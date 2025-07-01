-- 🚨 URGENT FIX pentru recursiunea infinită în Supabase
-- Rulează acest SQL în Supabase Dashboard → SQL Editor

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
    FOR r IN (SELECT policyname FROM pg_policies WHERE tablename = 'profiles') LOOP
        EXECUTE 'DROP POLICY IF EXISTS "' || r.policyname || '" ON profiles';
    END LOOP;
    
    -- Șterge toate politicile pentru listings
    FOR r IN (SELECT policyname FROM pg_policies WHERE tablename = 'listings') LOOP
        EXECUTE 'DROP POLICY IF EXISTS "' || r.policyname || '" ON listings';
    END LOOP;
    
    -- Șterge toate politicile pentru favorites
    FOR r IN (SELECT policyname FROM pg_policies WHERE tablename = 'favorites') LOOP
        EXECUTE 'DROP POLICY IF EXISTS "' || r.policyname || '" ON favorites';
    END LOOP;
END $$;

-- Pasul 3: Reactivează RLS
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE listings ENABLE ROW LEVEL SECURITY;
ALTER TABLE favorites ENABLE ROW LEVEL SECURITY;

-- Pasul 4: Creează politici SIMPLE fără recursiune pentru PROFILES
CREATE POLICY "allow_all_profiles_read" ON profiles
  FOR SELECT USING (true);

CREATE POLICY "allow_own_profile_update" ON profiles
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "allow_own_profile_insert" ON profiles
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Pasul 5: Creează politici SIMPLE fără recursiune pentru LISTINGS
CREATE POLICY "allow_active_listings_read" ON listings
  FOR SELECT USING (status = 'active');

CREATE POLICY "allow_authenticated_listings_insert" ON listings
  FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);

CREATE POLICY "allow_own_listings_update" ON listings
  FOR UPDATE USING (
    auth.uid() IS NOT NULL AND 
    EXISTS (SELECT 1 FROM profiles WHERE user_id = auth.uid() AND id = listings.seller_id)
  );

CREATE POLICY "allow_own_listings_delete" ON listings
  FOR DELETE USING (
    auth.uid() IS NOT NULL AND 
    EXISTS (SELECT 1 FROM profiles WHERE user_id = auth.uid() AND id = listings.seller_id)
  );

-- Pasul 6: Creează politici SIMPLE pentru FAVORITES
CREATE POLICY "allow_own_favorites_read" ON favorites
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "allow_own_favorites_insert" ON favorites
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "allow_own_favorites_delete" ON favorites
  FOR DELETE USING (auth.uid() = user_id);

-- Pasul 7: Asigură-te că funcția pentru utilizatori noi funcționează
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
    COALESCE(NEW.raw_user_meta_data->>'name', 'Utilizator'),
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'phone', ''),
    COALESCE(NEW.raw_user_meta_data->>'location', ''),
    COALESCE(NEW.raw_user_meta_data->>'sellerType', 'individual')
  );
  RETURN NEW;
EXCEPTION
  WHEN OTHERS THEN
    -- Dacă crearea profilului eșuează, permite totuși crearea utilizatorului
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Pasul 8: Recreează trigger-ul
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- Pasul 9: Asigură-te că tabelele există cu structura corectă
CREATE TABLE IF NOT EXISTS profiles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE UNIQUE,
  name text NOT NULL,
  email text UNIQUE NOT NULL,
  phone text,
  location text,
  description text,
  website text,
  avatar_url text,
  verified boolean DEFAULT false,
  seller_type text DEFAULT 'individual' CHECK (seller_type IN ('individual', 'dealer')),
  rating numeric(3,2) DEFAULT 0,
  reviews_count integer DEFAULT 0,
  is_admin boolean DEFAULT false,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS listings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title text NOT NULL,
  description text,
  price numeric(10,2) NOT NULL,
  currency text DEFAULT 'EUR',
  year integer NOT NULL,
  mileage integer NOT NULL,
  location text NOT NULL,
  category text NOT NULL CHECK (category IN ('sport', 'touring', 'cruiser', 'adventure', 'naked', 'enduro', 'scooter', 'chopper')),
  brand text NOT NULL,
  model text NOT NULL,
  engine_capacity integer NOT NULL,
  fuel_type text NOT NULL CHECK (fuel_type IN ('benzina', 'electric', 'hibrid')),
  transmission text NOT NULL CHECK (transmission IN ('manuala', 'automata', 'semi-automata')),
  condition text NOT NULL CHECK (condition IN ('noua', 'excelenta', 'foarte_buna', 'buna', 'satisfacatoare')),
  color text,
  images text[] DEFAULT '{}',
  features text[] DEFAULT '{}',
  seller_id uuid REFERENCES profiles(id) ON DELETE CASCADE,
  seller_name text NOT NULL,
  seller_type text NOT NULL,
  rating numeric(3,2) DEFAULT 0,
  views_count integer DEFAULT 0,
  favorites_count integer DEFAULT 0,
  featured boolean DEFAULT false,
  status text DEFAULT 'active' CHECK (status IN ('active', 'sold', 'pending', 'rejected')),
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS favorites (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
  listing_id uuid REFERENCES listings(id) ON DELETE CASCADE,
  created_at timestamptz DEFAULT now(),
  UNIQUE(user_id, listing_id)
);

-- Pasul 10: Creează indexuri pentru performanță
CREATE INDEX IF NOT EXISTS idx_profiles_user_id ON profiles(user_id);
CREATE INDEX IF NOT EXISTS idx_profiles_email ON profiles(email);
CREATE INDEX IF NOT EXISTS idx_listings_seller_id ON listings(seller_id);
CREATE INDEX IF NOT EXISTS idx_listings_status ON listings(status);
CREATE INDEX IF NOT EXISTS idx_listings_created_at ON listings(created_at);
CREATE INDEX IF NOT EXISTS idx_favorites_user_id ON favorites(user_id);
CREATE INDEX IF NOT EXISTS idx_favorites_listing_id ON favorites(listing_id);

-- Pasul 11: Test final - acestea ar trebui să funcționeze fără erori
SELECT 'Profiles count:' as info, COUNT(*) as count FROM profiles
UNION ALL
SELECT 'Active listings count:' as info, COUNT(*) as count FROM listings WHERE status = 'active'
UNION ALL
SELECT 'Favorites count:' as info, COUNT(*) as count FROM favorites;

-- Dacă vezi rezultate fără erori, fix-ul a funcționat!