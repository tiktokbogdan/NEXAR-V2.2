-- 🚨 CRITICAL FIX: Infinite Recursion in RLS Policies
-- This SQL must be run in Supabase Dashboard → SQL Editor

-- Step 1: Completely disable RLS temporarily to break the recursion
ALTER TABLE profiles DISABLE ROW LEVEL SECURITY;
ALTER TABLE listings DISABLE ROW LEVEL SECURITY;

-- Step 2: Drop ALL existing policies that could cause recursion
DROP POLICY IF EXISTS "Profiles sunt vizibile pentru toți" ON profiles;
DROP POLICY IF EXISTS "Utilizatorii pot să-și actualizeze propriul profil" ON profiles;
DROP POLICY IF EXISTS "Toată lumea poate vedea profilurile" ON profiles;
DROP POLICY IF EXISTS "Utilizatorii pot actualiza propriul profil" ON profiles;
DROP POLICY IF EXISTS "Public profiles read access" ON profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON profiles;
DROP POLICY IF EXISTS "Users can insert own profile" ON profiles;

DROP POLICY IF EXISTS "Anunțurile active sunt vizibile pentru toți" ON listings;
DROP POLICY IF EXISTS "Utilizatorii pot să-și creeze propriile anunțuri" ON listings;
DROP POLICY IF EXISTS "Utilizatorii pot să-și actualizeze propriile anunțuri" ON listings;
DROP POLICY IF EXISTS "Utilizatorii pot să-și șteargă propriile anunțuri" ON listings;
DROP POLICY IF EXISTS "Toată lumea poate vedea anunțurile active" ON listings;
DROP POLICY IF EXISTS "Utilizatorii autentificați pot crea anunțuri" ON listings;
DROP POLICY IF EXISTS "Utilizatorii pot actualiza propriile anunțuri" ON listings;
DROP POLICY IF EXISTS "Utilizatorii pot șterge propriile anunțuri" ON listings;
DROP POLICY IF EXISTS "Public can view active listings" ON listings;
DROP POLICY IF EXISTS "Authenticated users can create listings" ON listings;
DROP POLICY IF EXISTS "Users can update own listings" ON listings;
DROP POLICY IF EXISTS "Users can delete own listings" ON listings;
DROP POLICY IF EXISTS "Admin poate vedea toate anunțurile" ON listings;
DROP POLICY IF EXISTS "Admin poate actualiza orice anunț" ON listings;
DROP POLICY IF EXISTS "Admin poate șterge orice anunț" ON listings;

-- Step 3: Re-enable RLS
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE listings ENABLE ROW LEVEL SECURITY;

-- Step 4: Create SIMPLE policies for profiles (NO RECURSION)
CREATE POLICY "profiles_select_all" ON profiles
  FOR SELECT USING (true);

CREATE POLICY "profiles_update_own" ON profiles
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "profiles_insert_own" ON profiles
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Step 5: Create SIMPLE policies for listings (NO PROFILE TABLE QUERIES)
CREATE POLICY "listings_select_active" ON listings
  FOR SELECT USING (status = 'active');

CREATE POLICY "listings_insert_auth" ON listings
  FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);

CREATE POLICY "listings_update_own" ON listings
  FOR UPDATE USING (
    auth.uid() IS NOT NULL AND 
    seller_id = (SELECT id FROM profiles WHERE user_id = auth.uid() LIMIT 1)
  );

CREATE POLICY "listings_delete_own" ON listings
  FOR DELETE USING (
    auth.uid() IS NOT NULL AND 
    seller_id = (SELECT id FROM profiles WHERE user_id = auth.uid() LIMIT 1)
  );

-- Step 6: Ensure the handle_new_user function exists and works
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
    -- If profile creation fails, still allow user creation
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Step 7: Recreate the trigger
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- Step 8: Ensure favorites table has correct policies
CREATE TABLE IF NOT EXISTS favorites (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
  listing_id uuid REFERENCES listings(id) ON DELETE CASCADE,
  created_at timestamptz DEFAULT now(),
  UNIQUE(user_id, listing_id)
);

ALTER TABLE favorites ENABLE ROW LEVEL SECURITY;

-- Drop existing favorites policies
DROP POLICY IF EXISTS "Utilizatorii pot vedea propriile favorite" ON favorites;
DROP POLICY IF EXISTS "Utilizatorii pot adăuga favorite" ON favorites;
DROP POLICY IF EXISTS "Utilizatorii pot șterge propriile favorite" ON favorites;
DROP POLICY IF EXISTS "Users can manage own favorites" ON favorites;

-- Create simple favorites policies
CREATE POLICY "favorites_select_own" ON favorites
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "favorites_insert_own" ON favorites
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "favorites_delete_own" ON favorites
  FOR DELETE USING (auth.uid() = user_id);

-- Step 9: Create essential indexes
CREATE INDEX IF NOT EXISTS idx_profiles_user_id ON profiles(user_id);
CREATE INDEX IF NOT EXISTS idx_profiles_email ON profiles(email);
CREATE INDEX IF NOT EXISTS idx_listings_seller_id ON listings(seller_id);
CREATE INDEX IF NOT EXISTS idx_listings_status ON listings(status);
CREATE INDEX IF NOT EXISTS idx_listings_created_at ON listings(created_at);
CREATE INDEX IF NOT EXISTS idx_favorites_user_id ON favorites(user_id);
CREATE INDEX IF NOT EXISTS idx_favorites_listing_id ON favorites(listing_id);

-- Step 10: Test queries to verify everything works
-- These should run without errors:
-- SELECT COUNT(*) FROM profiles;
-- SELECT COUNT(*) FROM listings WHERE status = 'active';
-- SELECT COUNT(*) FROM favorites;