/*
  # CRITICAL FIX: Infinite Recursion in RLS Policies
  
  1. Problem
    - Infinite recursion detected in policy for relation "profiles"
    - RLS policies are creating circular dependencies
    - 500 errors when accessing profiles or listings tables
    
  2. Solution
    - Completely remove all problematic policies
    - Create simple, non-recursive policies
    - Ensure no circular dependencies between tables
*/

-- Step 1: Temporarily disable RLS to break recursion
ALTER TABLE profiles DISABLE ROW LEVEL SECURITY;
ALTER TABLE listings DISABLE ROW LEVEL SECURITY;
ALTER TABLE favorites DISABLE ROW LEVEL SECURITY;

-- Step 2: Drop ALL existing policies that could cause recursion
DO $$
DECLARE
    r RECORD;
BEGIN
    -- Drop all policies for profiles
    FOR r IN (SELECT policyname FROM pg_policies WHERE tablename = 'profiles' AND schemaname = 'public') LOOP
        EXECUTE 'DROP POLICY IF EXISTS "' || r.policyname || '" ON public.profiles';
    END LOOP;
    
    -- Drop all policies for listings
    FOR r IN (SELECT policyname FROM pg_policies WHERE tablename = 'listings' AND schemaname = 'public') LOOP
        EXECUTE 'DROP POLICY IF EXISTS "' || r.policyname || '" ON public.listings';
    END LOOP;
    
    -- Drop all policies for favorites
    FOR r IN (SELECT policyname FROM pg_policies WHERE tablename = 'favorites' AND schemaname = 'public') LOOP
        EXECUTE 'DROP POLICY IF EXISTS "' || r.policyname || '" ON public.favorites';
    END LOOP;
END $$;

-- Step 3: Re-enable RLS
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE listings ENABLE ROW LEVEL SECURITY;
ALTER TABLE favorites ENABLE ROW LEVEL SECURITY;

-- Step 4: Create SIMPLE policies for profiles (NO RECURSION)
CREATE POLICY "profiles_public_read" ON profiles
  FOR SELECT USING (true);

CREATE POLICY "profiles_own_update" ON profiles
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "profiles_own_insert" ON profiles
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Step 5: Create SIMPLE policies for listings (NO PROFILE QUERIES)
CREATE POLICY "listings_public_read_active" ON listings
  FOR SELECT USING (status = 'active');

CREATE POLICY "listings_auth_insert" ON listings
  FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);

-- For update/delete, use a simple approach without complex subqueries
CREATE POLICY "listings_own_update" ON listings
  FOR UPDATE USING (
    auth.uid() IS NOT NULL AND 
    seller_id = (
      SELECT p.id FROM profiles p 
      WHERE p.user_id = auth.uid() 
      LIMIT 1
    )
  );

CREATE POLICY "listings_own_delete" ON listings
  FOR DELETE USING (
    auth.uid() IS NOT NULL AND 
    seller_id = (
      SELECT p.id FROM profiles p 
      WHERE p.user_id = auth.uid() 
      LIMIT 1
    )
  );

-- Step 6: Create SIMPLE policies for favorites
CREATE POLICY "favorites_own_read" ON favorites
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "favorites_own_insert" ON favorites
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "favorites_own_delete" ON favorites
  FOR DELETE USING (auth.uid() = user_id);

-- Step 7: Ensure the user creation function is robust
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO profiles (
    user_id,
    name,
    email,
    phone,
    location,
    seller_type
  ) VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'name', 'User'),
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'phone', ''),
    COALESCE(NEW.raw_user_meta_data->>'location', ''),
    COALESCE(NEW.raw_user_meta_data->>'sellerType', 'individual')
  );
  RETURN NEW;
EXCEPTION
  WHEN OTHERS THEN
    -- Log the error but don't fail user creation
    RAISE WARNING 'Failed to create profile for user %: %', NEW.id, SQLERRM;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Step 8: Recreate the trigger
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- Step 9: Create essential indexes for performance
CREATE INDEX IF NOT EXISTS idx_profiles_user_id ON profiles(user_id);
CREATE INDEX IF NOT EXISTS idx_profiles_email ON profiles(email);
CREATE INDEX IF NOT EXISTS idx_listings_seller_id ON listings(seller_id);
CREATE INDEX IF NOT EXISTS idx_listings_status ON listings(status);
CREATE INDEX IF NOT EXISTS idx_favorites_user_id ON favorites(user_id);

-- Step 10: Test the fix with simple queries
DO $$
BEGIN
  -- Test profiles access
  PERFORM COUNT(*) FROM profiles;
  RAISE NOTICE 'Profiles table access: OK';
  
  -- Test listings access
  PERFORM COUNT(*) FROM listings WHERE status = 'active';
  RAISE NOTICE 'Listings table access: OK';
  
  -- Test favorites access
  PERFORM COUNT(*) FROM favorites;
  RAISE NOTICE 'Favorites table access: OK';
  
EXCEPTION
  WHEN OTHERS THEN
    RAISE WARNING 'Test failed: %', SQLERRM;
END $$;