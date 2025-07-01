/*
  # Creează tabela profiles și trigger-ul pentru utilizatori noi

  1. Tabele noi
    - `profiles` - profiluri utilizatori cu toate coloanele necesare

  2. Securitate
    - Enable RLS pe tabela profiles
    - Politici pentru accesul la date
    - Trigger pentru crearea automată a profilurilor

  3. Funcții
    - Funcție pentru gestionarea utilizatorilor noi
*/

-- Creează tabela profiles dacă nu există
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

-- Enable Row Level Security
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

-- Politici RLS pentru profiles
CREATE POLICY "Profiles sunt vizibile pentru toți" ON profiles
  FOR SELECT USING (true);

CREATE POLICY "Utilizatorii pot să-și actualizeze propriul profil" ON profiles
  FOR UPDATE USING (auth.uid() = user_id);

-- Funcție pentru gestionarea utilizatorilor noi
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
    COALESCE(NEW.raw_user_meta_data->>'name', ''),
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'phone', ''),
    COALESCE(NEW.raw_user_meta_data->>'location', ''),
    COALESCE(NEW.raw_user_meta_data->>'sellerType', 'individual')
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger pentru crearea automată a profilurilor
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- Funcție pentru actualizarea timestamp-urilor
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ language 'plpgsql';

-- Trigger pentru actualizarea automată a updated_at
CREATE TRIGGER update_profiles_updated_at BEFORE UPDATE ON profiles
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Indexuri pentru performanță
CREATE INDEX IF NOT EXISTS idx_profiles_user_id ON profiles(user_id);
CREATE INDEX IF NOT EXISTS idx_profiles_email ON profiles(email);
CREATE INDEX IF NOT EXISTS idx_profiles_name ON profiles(name);
CREATE INDEX IF NOT EXISTS idx_profiles_location ON profiles(location);
CREATE INDEX IF NOT EXISTS idx_profiles_seller_type ON profiles(seller_type);