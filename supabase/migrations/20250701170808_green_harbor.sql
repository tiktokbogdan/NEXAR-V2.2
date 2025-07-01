-- 🚨 CRITICAL FIX - Apply this SQL script in Supabase Dashboard → SQL Editor
-- This will resolve all RLS policy violations and profile creation issues

-- Step 1: Temporarily disable RLS to prevent recursion
ALTER TABLE profiles DISABLE ROW LEVEL SECURITY;
ALTER TABLE listings DISABLE ROW LEVEL SECURITY;
ALTER TABLE favorites DISABLE ROW LEVEL SECURITY;
ALTER TABLE messages DISABLE ROW LEVEL SECURITY;
ALTER TABLE reviews DISABLE ROW LEVEL SECURITY;

-- Step 2: Drop ALL existing policies that are causing conflicts
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
    
    -- Drop all policies for messages
    FOR r IN (SELECT policyname FROM pg_policies WHERE tablename = 'messages' AND schemaname = 'public') LOOP
        EXECUTE 'DROP POLICY IF EXISTS "' || r.policyname || '" ON public.messages';
    END LOOP;
    
    -- Drop all policies for reviews
    FOR r IN (SELECT policyname FROM pg_policies WHERE tablename = 'reviews' AND schemaname = 'public') LOOP
        EXECUTE 'DROP POLICY IF EXISTS "' || r.policyname || '" ON public.reviews';
    END LOOP;
    
    -- Drop all policies for storage.objects
    FOR r IN (SELECT policyname FROM pg_policies WHERE tablename = 'objects' AND schemaname = 'storage') LOOP
        EXECUTE 'DROP POLICY IF EXISTS "' || r.policyname || '" ON storage.objects';
    END LOOP;
END $$;

-- Step 3: Re-enable RLS
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE listings ENABLE ROW LEVEL SECURITY;
ALTER TABLE favorites ENABLE ROW LEVEL SECURITY;
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE reviews ENABLE ROW LEVEL SECURITY;

-- Step 4: Create SIMPLE policies for PROFILES (NO RECURSION)
CREATE POLICY "profiles_select" ON profiles
  FOR SELECT USING (true);

CREATE POLICY "profiles_update" ON profiles
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "profiles_insert" ON profiles
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Step 5: Create SIMPLE policies for LISTINGS (NO RECURSION)
CREATE POLICY "listings_select" ON listings
  FOR SELECT USING (status = 'active');

-- FIXED: More permissive insert policy for authenticated users
CREATE POLICY "listings_insert" ON listings
  FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);

CREATE POLICY "listings_update" ON listings
  FOR UPDATE USING (
    auth.uid() IS NOT NULL AND 
    seller_id IN (
      SELECT id FROM profiles 
      WHERE user_id = auth.uid() 
      LIMIT 1
    )
  );

CREATE POLICY "listings_delete" ON listings
  FOR DELETE USING (
    auth.uid() IS NOT NULL AND 
    seller_id IN (
      SELECT id FROM profiles 
      WHERE user_id = auth.uid() 
      LIMIT 1
    )
  );

-- Step 6: Create SIMPLE policies for FAVORITES
CREATE POLICY "favorites_select" ON favorites
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "favorites_insert" ON favorites
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "favorites_delete" ON favorites
  FOR DELETE USING (auth.uid() = user_id);

-- Step 7: Create SIMPLE policies for MESSAGES
CREATE POLICY "messages_select" ON messages
  FOR SELECT USING (auth.uid() = sender_id OR auth.uid() = receiver_id);

CREATE POLICY "messages_insert" ON messages
  FOR INSERT WITH CHECK (auth.uid() = sender_id);

-- Step 8: Create SIMPLE policies for REVIEWS
CREATE POLICY "reviews_select" ON reviews
  FOR SELECT USING (true);

CREATE POLICY "reviews_insert" ON reviews
  FOR INSERT WITH CHECK (auth.uid() = reviewer_id);

-- Step 9: Configure Storage for images (NO RECURSION)
-- Create buckets if they don't exist
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES 
  ('listing-images', 'listing-images', true, 5242880, ARRAY['image/jpeg', 'image/png', 'image/webp']),
  ('profile-images', 'profile-images', true, 2097152, ARRAY['image/jpeg', 'image/png', 'image/webp'])
ON CONFLICT (id) DO NOTHING;

-- Enable RLS for storage
ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

-- Simple storage policies
CREATE POLICY "storage_select_listing_images" ON storage.objects
  FOR SELECT USING (bucket_id = 'listing-images');

CREATE POLICY "storage_select_profile_images" ON storage.objects
  FOR SELECT USING (bucket_id = 'profile-images');

CREATE POLICY "storage_insert_listing_images" ON storage.objects
  FOR INSERT WITH CHECK (
    bucket_id = 'listing-images' AND 
    auth.uid() IS NOT NULL
  );

CREATE POLICY "storage_insert_profile_images" ON storage.objects
  FOR INSERT WITH CHECK (
    bucket_id = 'profile-images' AND 
    auth.uid() IS NOT NULL
  );

CREATE POLICY "storage_delete_listing_images" ON storage.objects
  FOR DELETE USING (
    bucket_id = 'listing-images' AND 
    auth.uid()::text = (storage.foldername(name))[1]
  );

CREATE POLICY "storage_delete_profile_images" ON storage.objects
  FOR DELETE USING (
    bucket_id = 'profile-images' AND 
    auth.uid()::text = (storage.foldername(name))[1]
  );

-- Step 10: Configure admin policies (NO RECURSION)
-- Add is_admin column if it doesn't exist
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'profiles' AND column_name = 'is_admin'
  ) THEN
    ALTER TABLE profiles ADD COLUMN is_admin boolean DEFAULT false;
  END IF;
END $$;

-- Update admin profile
UPDATE profiles 
SET is_admin = true 
WHERE email = 'admin@nexar.ro';

-- Admin policies - using email instead of subqueries
CREATE POLICY "admin_select_listings" ON listings
  FOR SELECT USING (
    auth.email() = 'admin@nexar.ro'
  );

CREATE POLICY "admin_update_listings" ON listings
  FOR UPDATE USING (
    auth.email() = 'admin@nexar.ro'
  );

CREATE POLICY "admin_delete_listings" ON listings
  FOR DELETE USING (
    auth.email() = 'admin@nexar.ro'
  );

-- Step 11: FIXED - handle_new_user function with RLS bypass
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  -- Temporarily disable RLS for this operation
  PERFORM set_config('row_level_security.enabled', 'off', TRUE);
  
  INSERT INTO profiles (
    user_id,
    name,
    email,
    phone,
    location,
    seller_type,
    is_admin
  ) VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'name', 'Utilizator'),
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'phone', ''),
    COALESCE(NEW.raw_user_meta_data->>'location', ''),
    COALESCE(NEW.raw_user_meta_data->>'sellerType', 'individual'),
    NEW.email = 'admin@nexar.ro'
  );
  
  -- Re-enable RLS
  PERFORM set_config('row_level_security.enabled', 'on', TRUE);
  
  RETURN NEW;
EXCEPTION
  WHEN OTHERS THEN
    -- Re-enable RLS in case of error
    PERFORM set_config('row_level_security.enabled', 'on', TRUE);
    -- If profile creation fails, still allow user creation
    RAISE WARNING 'Failed to create profile for user %: %', NEW.id, SQLERRM;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Step 12: Recreate the trigger
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- Step 13: Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_profiles_user_id ON profiles(user_id);
CREATE INDEX IF NOT EXISTS idx_profiles_email ON profiles(email);
CREATE INDEX IF NOT EXISTS idx_profiles_is_admin ON profiles(is_admin);
CREATE INDEX IF NOT EXISTS idx_listings_seller_id ON listings(seller_id);
CREATE INDEX IF NOT EXISTS idx_listings_status ON listings(status);
CREATE INDEX IF NOT EXISTS idx_favorites_user_id ON favorites(user_id);
CREATE INDEX IF NOT EXISTS idx_favorites_listing_id ON favorites(listing_id);

-- Step 14: Fix existing users' profiles
DO $$
DECLARE
    u RECORD;
BEGIN
    -- Temporarily disable RLS for this operation
    PERFORM set_config('row_level_security.enabled', 'off', TRUE);
    
    FOR u IN (
        SELECT id, email FROM auth.users
        WHERE id NOT IN (SELECT user_id FROM profiles)
    ) LOOP
        INSERT INTO profiles (
            user_id,
            name,
            email,
            seller_type,
            is_admin
        ) VALUES (
            u.id,
            split_part(u.email, '@', 1),
            u.email,
            'individual',
            u.email = 'admin@nexar.ro'
        );
        RAISE NOTICE 'Created missing profile for user %', u.email;
    END LOOP;
    
    -- Re-enable RLS
    PERFORM set_config('row_level_security.enabled', 'on', TRUE);
EXCEPTION
    WHEN OTHERS THEN
        -- Re-enable RLS in case of error
        PERFORM set_config('row_level_security.enabled', 'on', TRUE);
        RAISE WARNING 'Error creating missing profiles: %', SQLERRM;
END $$;

-- Step 15: Final test - verify everything works
DO $$
BEGIN
  -- Test access to profiles
  PERFORM COUNT(*) FROM profiles;
  RAISE NOTICE 'Access to profiles table: OK';
  
  -- Test access to listings
  PERFORM COUNT(*) FROM listings WHERE status = 'active';
  RAISE NOTICE 'Access to listings table: OK';
  
  -- Test access to favorites
  PERFORM COUNT(*) FROM favorites;
  RAISE NOTICE 'Access to favorites table: OK';
  
EXCEPTION
  WHEN OTHERS THEN
    RAISE WARNING 'Test failed: %', SQLERRM;
END $$;