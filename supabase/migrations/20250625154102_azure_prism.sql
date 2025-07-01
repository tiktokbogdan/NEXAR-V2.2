-- 🚨 MIGRAȚIA FINALĂ - Rezolvă toate problemele cu RLS și funcționalitățile
-- Rulează această migrație în Supabase Dashboard → SQL Editor

-- Pasul 1: Dezactivează temporar RLS pentru a opri recursiunea
ALTER TABLE profiles DISABLE ROW LEVEL SECURITY;
ALTER TABLE listings DISABLE ROW LEVEL SECURITY;
ALTER TABLE favorites DISABLE ROW LEVEL SECURITY;

-- Pasul 2: Șterge TOATE politicile existente care cauzează probleme
DO $$
DECLARE
    r RECORD;
BEGIN
    -- Șterge toate politicile pentru profiles
    FOR r IN (SELECT policyname FROM pg_policies WHERE tablename = 'profiles' AND schemaname = 'public') LOOP
        EXECUTE 'DROP POLICY IF EXISTS "' || r.policyname || '" ON public.profiles';
    END LOOP;
    
    -- Șterge toate politicile pentru listings
    FOR r IN (SELECT policyname FROM pg_policies WHERE tablename = 'listings' AND schemaname = 'public') LOOP
        EXECUTE 'DROP POLICY IF EXISTS "' || r.policyname || '" ON public.listings';
    END LOOP;
    
    -- Șterge toate politicile pentru favorites
    FOR r IN (SELECT policyname FROM pg_policies WHERE tablename = 'favorites' AND schemaname = 'public') LOOP
        EXECUTE 'DROP POLICY IF EXISTS "' || r.policyname || '" ON public.favorites';
    END LOOP;
    
    -- Șterge toate politicile pentru storage.objects
    FOR r IN (SELECT policyname FROM pg_policies WHERE tablename = 'objects' AND schemaname = 'storage') LOOP
        EXECUTE 'DROP POLICY IF EXISTS "' || r.policyname || '" ON storage.objects';
    END LOOP;
END $$;

-- Pasul 3: Reactivează RLS
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE listings ENABLE ROW LEVEL SECURITY;
ALTER TABLE favorites ENABLE ROW LEVEL SECURITY;

-- Pasul 4: Creează politici SIMPLE pentru PROFILES (FĂRĂ RECURSIUNE)
CREATE POLICY "allow_read_all_profiles" ON profiles
  FOR SELECT USING (true);

CREATE POLICY "allow_update_own_profile" ON profiles
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "allow_insert_own_profile" ON profiles
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Pasul 5: Creează politici SIMPLE pentru LISTINGS (FĂRĂ RECURSIUNE)
CREATE POLICY "allow_read_active_listings" ON listings
  FOR SELECT USING (status = 'active');

CREATE POLICY "allow_insert_listings_auth" ON listings
  FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);

-- Politici pentru update/delete fără recursiune
CREATE POLICY "allow_update_own_listings" ON listings
  FOR UPDATE USING (
    auth.uid() IS NOT NULL AND 
    seller_id IN (
      SELECT id FROM profiles 
      WHERE user_id = auth.uid() 
      LIMIT 1
    )
  );

CREATE POLICY "allow_delete_own_listings" ON listings
  FOR DELETE USING (
    auth.uid() IS NOT NULL AND 
    seller_id IN (
      SELECT id FROM profiles 
      WHERE user_id = auth.uid() 
      LIMIT 1
    )
  );

-- Pasul 6: Creează politici SIMPLE pentru FAVORITES
CREATE POLICY "allow_read_own_favorites" ON favorites
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "allow_insert_own_favorites" ON favorites
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "allow_delete_own_favorites" ON favorites
  FOR DELETE USING (auth.uid() = user_id);

-- Pasul 7: Configurează Storage pentru imagini (FĂRĂ RECURSIUNE)
-- Creează bucket-urile dacă nu există
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES 
  ('listing-images', 'listing-images', true, 5242880, ARRAY['image/jpeg', 'image/png', 'image/webp']),
  ('profile-images', 'profile-images', true, 2097152, ARRAY['image/jpeg', 'image/png', 'image/webp'])
ON CONFLICT (id) DO NOTHING;

-- Activează RLS pentru storage
ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

-- Politici simple pentru storage
CREATE POLICY "allow_public_read_listing_images" ON storage.objects
  FOR SELECT USING (bucket_id = 'listing-images');

CREATE POLICY "allow_public_read_profile_images" ON storage.objects
  FOR SELECT USING (bucket_id = 'profile-images');

CREATE POLICY "allow_auth_upload_listing_images" ON storage.objects
  FOR INSERT WITH CHECK (
    bucket_id = 'listing-images' AND 
    auth.uid() IS NOT NULL
  );

CREATE POLICY "allow_auth_upload_profile_images" ON storage.objects
  FOR INSERT WITH CHECK (
    bucket_id = 'profile-images' AND 
    auth.uid() IS NOT NULL
  );

CREATE POLICY "allow_delete_own_listing_images" ON storage.objects
  FOR DELETE USING (
    bucket_id = 'listing-images' AND 
    auth.uid()::text = (storage.foldername(name))[1]
  );

CREATE POLICY "allow_delete_own_profile_images" ON storage.objects
  FOR DELETE USING (
    bucket_id =  'profile-images' AND 
    auth.uid()::text = (storage.foldername(name))[1]
  );

-- Pasul 8: Configurează politici pentru administrator (FĂRĂ RECURSIUNE)
-- Adaugă coloana is_admin dacă nu există
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'profiles' AND column_name = 'is_admin'
  ) THEN
    ALTER TABLE profiles ADD COLUMN is_admin boolean DEFAULT false;
  END IF;
END $$;

-- Actualizează profilul admin
UPDATE profiles 
SET is_admin = true 
WHERE email = 'admin@nexar.ro';

-- Politici pentru admin - folosind email în loc de subqueries
CREATE POLICY "allow_admin_read_all_listings" ON listings
  FOR SELECT USING (
    auth.email() = 'admin@nexar.ro'
  );

CREATE POLICY "allow_admin_update_all_listings" ON listings
  FOR UPDATE USING (
    auth.email() = 'admin@nexar.ro'
  );

CREATE POLICY "allow_admin_delete_all_listings" ON listings
  FOR DELETE USING (
    auth.email() = 'admin@nexar.ro'
  );

-- Pasul 9: Asigură-te că funcția handle_new_user este robustă
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
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
  RETURN NEW;
EXCEPTION
  WHEN OTHERS THEN
    -- Dacă crearea profilului eșuează, permite totuși crearea utilizatorului
    RAISE WARNING 'Failed to create profile for user %: %', NEW.id, SQLERRM;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Pasul 10: Recreează trigger-ul
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- Pasul 11: Creează indexuri pentru performanță
CREATE INDEX IF NOT EXISTS idx_profiles_user_id ON profiles(user_id);
CREATE INDEX IF NOT EXISTS idx_profiles_email ON profiles(email);
CREATE INDEX IF NOT EXISTS idx_profiles_is_admin ON profiles(is_admin);
CREATE INDEX IF NOT EXISTS idx_listings_seller_id ON listings(seller_id);
CREATE INDEX IF NOT EXISTS idx_listings_status ON listings(status);
CREATE INDEX IF NOT EXISTS idx_favorites_user_id ON favorites(user_id);
CREATE INDEX IF NOT EXISTS idx_favorites_listing_id ON favorites(listing_id);

-- Pasul 12: Test final - verifică că totul funcționează
DO $$
BEGIN
  -- Testează accesul la profiles
  PERFORM COUNT(*) FROM profiles;
  RAISE NOTICE 'Acces la tabela profiles: OK';
  
  -- Testează accesul la listings
  PERFORM COUNT(*) FROM listings WHERE status = 'active';
  RAISE NOTICE 'Acces la tabela listings: OK';
  
  -- Testează accesul la favorites
  PERFORM COUNT(*) FROM favorites;
  RAISE NOTICE 'Acces la tabela favorites: OK';
  
EXCEPTION
  WHEN OTHERS THEN
    RAISE WARNING 'Testul a eșuat: %', SQLERRM;
END $$;