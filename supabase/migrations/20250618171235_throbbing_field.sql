/*
  # Schema inițial pentru Nexar Motorcycle Marketplace

  1. Tabele noi
    - `profiles` - profiluri utilizatori
    - `listings` - anunțuri motociclete
    - `favorites` - anunțuri favorite
    - `messages` - mesaje între utilizatori
    - `reviews` - recenzii utilizatori

  2. Securitate
    - Enable RLS pe toate tabelele
    - Politici pentru accesul la date
*/

-- Tabela pentru profiluri utilizatori
CREATE TABLE IF NOT EXISTS profiles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
  name text NOT NULL,
  email text UNIQUE NOT NULL,
  phone text,
  location text,
  avatar_url text,
  verified boolean DEFAULT false,
  seller_type text DEFAULT 'individual' CHECK (seller_type IN ('individual', 'dealer')),
  rating numeric(3,2) DEFAULT 0,
  reviews_count integer DEFAULT 0,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Tabela pentru anunțuri
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

-- Tabela pentru favorite
CREATE TABLE IF NOT EXISTS favorites (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
  listing_id uuid REFERENCES listings(id) ON DELETE CASCADE,
  created_at timestamptz DEFAULT now(),
  UNIQUE(user_id, listing_id)
);

-- Tabela pentru mesaje
CREATE TABLE IF NOT EXISTS messages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sender_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
  receiver_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
  listing_id uuid REFERENCES listings(id) ON DELETE CASCADE,
  subject text,
  content text NOT NULL,
  read boolean DEFAULT false,
  created_at timestamptz DEFAULT now()
);

-- Tabela pentru recenzii
CREATE TABLE IF NOT EXISTS reviews (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  reviewer_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
  reviewed_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
  listing_id uuid REFERENCES listings(id) ON DELETE CASCADE,
  rating integer NOT NULL CHECK (rating >= 1 AND rating <= 5),
  comment text,
  created_at timestamptz DEFAULT now(),
  UNIQUE(reviewer_id, reviewed_id, listing_id)
);

-- Enable Row Level Security
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE listings ENABLE ROW LEVEL SECURITY;
ALTER TABLE favorites ENABLE ROW LEVEL SECURITY;
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE reviews ENABLE ROW LEVEL SECURITY;

-- Politici RLS pentru profiles
CREATE POLICY "Profiles sunt vizibile pentru toți" ON profiles
  FOR SELECT USING (true);

CREATE POLICY "Utilizatorii pot să-și actualizeze propriul profil" ON profiles
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Utilizatorii pot să-și creeze propriul profil" ON profiles
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Politici RLS pentru listings
CREATE POLICY "Anunțurile active sunt vizibile pentru toți" ON listings
  FOR SELECT USING (status = 'active');

CREATE POLICY "Utilizatorii pot să-și creeze propriile anunțuri" ON listings
  FOR INSERT WITH CHECK (auth.uid() = seller_id);

CREATE POLICY "Utilizatorii pot să-și actualizeze propriile anunțuri" ON listings
  FOR UPDATE USING (auth.uid() = seller_id);

CREATE POLICY "Utilizatorii pot să-și șteargă propriile anunțuri" ON listings
  FOR DELETE USING (auth.uid() = seller_id);

-- Politici RLS pentru favorites
CREATE POLICY "Utilizatorii pot vedea propriile favorite" ON favorites
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Utilizatorii pot adăuga favorite" ON favorites
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Utilizatorii pot șterge propriile favorite" ON favorites
  FOR DELETE USING (auth.uid() = user_id);

-- Politici RLS pentru messages
CREATE POLICY "Utilizatorii pot vedea mesajele lor" ON messages
  FOR SELECT USING (auth.uid() = sender_id OR auth.uid() = receiver_id);

CREATE POLICY "Utilizatorii pot trimite mesaje" ON messages
  FOR INSERT WITH CHECK (auth.uid() = sender_id);

-- Politici RLS pentru reviews
CREATE POLICY "Recenziile sunt vizibile pentru toți" ON reviews
  FOR SELECT USING (true);

CREATE POLICY "Utilizatorii pot lăsa recenzii" ON reviews
  FOR INSERT WITH CHECK (auth.uid() = reviewer_id);

-- Funcții pentru actualizarea timestamp-urilor
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ language 'plpgsql';

-- Trigger-e pentru actualizarea automată a updated_at
CREATE TRIGGER update_profiles_updated_at BEFORE UPDATE ON profiles
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_listings_updated_at BEFORE UPDATE ON listings
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Indexuri pentru performanță
CREATE INDEX IF NOT EXISTS idx_listings_category ON listings(category);
CREATE INDEX IF NOT EXISTS idx_listings_brand ON listings(brand);
CREATE INDEX IF NOT EXISTS idx_listings_price ON listings(price);
CREATE INDEX IF NOT EXISTS idx_listings_year ON listings(year);
CREATE INDEX IF NOT EXISTS idx_listings_location ON listings(location);
CREATE INDEX IF NOT EXISTS idx_listings_status ON listings(status);
CREATE INDEX IF NOT EXISTS idx_listings_created_at ON listings(created_at);
CREATE INDEX IF NOT EXISTS idx_favorites_user_id ON favorites(user_id);
CREATE INDEX IF NOT EXISTS idx_messages_receiver_id ON messages(receiver_id);