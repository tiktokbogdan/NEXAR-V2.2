-- 🔧 URGENT FIX: Infinite Recursion in RLS Policies
-- Run this in Supabase Dashboard → SQL Editor

-- Step 1: Drop all existing policies to prevent conflicts
DROP POLICY IF EXISTS "Profiles sunt vizibile pentru toți" ON profiles;
DROP POLICY IF EXISTS "Utilizatorii pot să-și actualizeze propriul profil" ON profiles;
DROP POLICY IF EXISTS "Toată lumea poate vedea anunțurile active" ON listings;
DROP POLICY IF EXISTS "Utilizatorii autentificați pot crea anunțuri" ON listings;
DROP POLICY IF EXISTS "Utilizatorii pot actualiza propriile anunțuri" ON listings;
DROP POLICY IF EXISTS "Utilizatorii pot șterge propriile anunțuri" ON listings;

-- Step 2: Recreate profiles table policies (FIXED - no recursion)
CREATE POLICY "Public profiles read access" ON profiles
  FOR SELECT USING (true);

CREATE POLICY "Users can update own profile" ON profiles
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own profile" ON profiles
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Step 3: Recreate listings policies (FIXED - simplified to avoid recursion)
CREATE POLICY "Public can view active listings" ON listings
  FOR SELECT USING (status = 'active');

CREATE POLICY "Authenticated users can create listings" ON listings
  FOR INSERT WITH CHECK (
    auth.uid() IS NOT NULL AND 
    auth.uid() = (SELECT user_id FROM profiles WHERE id = seller_id)
  );

CREATE POLICY "Users can update own listings" ON listings
  FOR UPDATE USING (
    auth.uid() IS NOT NULL AND 
    auth.uid() = (SELECT user_id FROM profiles WHERE id = seller_id)
  );

CREATE POLICY "Users can delete own listings" ON listings
  FOR DELETE USING (
    auth.uid() IS NOT NULL AND 
    auth.uid() = (SELECT user_id FROM profiles WHERE id = seller_id)
  );

-- Step 4: Ensure all tables exist with correct structure
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

-- Step 5: Enable RLS on all tables
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE listings ENABLE ROW LEVEL SECURITY;

-- Step 6: Create or replace the user creation function
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
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Step 7: Create trigger for new users
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- Step 8: Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_profiles_user_id ON profiles(user_id);
CREATE INDEX IF NOT EXISTS idx_profiles_email ON profiles(email);
CREATE INDEX IF NOT EXISTS idx_listings_seller_id ON listings(seller_id);
CREATE INDEX IF NOT EXISTS idx_listings_status ON listings(status);
CREATE INDEX IF NOT EXISTS idx_listings_created_at ON listings(created_at);

-- Step 9: Create other necessary tables
CREATE TABLE IF NOT EXISTS favorites (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
  listing_id uuid REFERENCES listings(id) ON DELETE CASCADE,
  created_at timestamptz DEFAULT now(),
  UNIQUE(user_id, listing_id)
);

ALTER TABLE favorites ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage own favorites" ON favorites
  FOR ALL USING (auth.uid() = user_id);

-- Verification queries (run these after the above to check everything works)
-- SELECT COUNT(*) FROM profiles;
-- SELECT COUNT(*) FROM listings WHERE status = 'active';