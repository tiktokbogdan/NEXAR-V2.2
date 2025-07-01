/*
  # Corectează politicile RLS pentru tabela listings

  1. Modificări
    - Corectează politica de INSERT pentru listings
    - Asigură că seller_id se referă la profiles.id, nu la auth.users.id
    - Adaugă politici corecte pentru toate operațiunile

  2. Securitate
    - Permite utilizatorilor să creeze anunțuri
    - Permite utilizatorilor să-și editeze propriile anunțuri
    - Toată lumea poate vedea anunțurile active
*/

-- Creează tabela listings dacă nu există
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

-- Enable Row Level Security
ALTER TABLE listings ENABLE ROW LEVEL SECURITY;

-- Șterge politicile existente pentru a le recrea
DROP POLICY IF EXISTS "Anunțurile active sunt vizibile pentru toți" ON listings;
DROP POLICY IF EXISTS "Utilizatorii pot să-și creeze propriile anunțuri" ON listings;
DROP POLICY IF EXISTS "Utilizatorii pot să-și actualizeze propriile anunțuri" ON listings;
DROP POLICY IF EXISTS "Utilizatorii pot să-și șteargă propriile anunțuri" ON listings;

-- Politici RLS pentru listings - CORECTE
CREATE POLICY "Toată lumea poate vedea anunțurile active" ON listings
  FOR SELECT USING (status = 'active');

CREATE POLICY "Utilizatorii autentificați pot crea anunțuri" ON listings
  FOR INSERT WITH CHECK (
    auth.uid() IS NOT NULL AND 
    seller_id IN (SELECT id FROM profiles WHERE user_id = auth.uid())
  );

CREATE POLICY "Utilizatorii pot actualiza propriile anunțuri" ON listings
  FOR UPDATE USING (
    auth.uid() IS NOT NULL AND 
    seller_id IN (SELECT id FROM profiles WHERE user_id = auth.uid())
  );

CREATE POLICY "Utilizatorii pot șterge propriile anunțuri" ON listings
  FOR DELETE USING (
    auth.uid() IS NOT NULL AND 
    seller_id IN (SELECT id FROM profiles WHERE user_id = auth.uid())
  );

-- Creează tabela favorites dacă nu există
CREATE TABLE IF NOT EXISTS favorites (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
  listing_id uuid REFERENCES listings(id) ON DELETE CASCADE,
  created_at timestamptz DEFAULT now(),
  UNIQUE(user_id, listing_id)
);

-- Enable RLS pentru favorites
ALTER TABLE favorites ENABLE ROW LEVEL SECURITY;

-- Politici pentru favorites
DROP POLICY IF EXISTS "Utilizatorii pot vedea propriile favorite" ON favorites;
DROP POLICY IF EXISTS "Utilizatorii pot adăuga favorite" ON favorites;
DROP POLICY IF EXISTS "Utilizatorii pot șterge propriile favorite" ON favorites;

CREATE POLICY "Utilizatorii pot vedea propriile favorite" ON favorites
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Utilizatorii pot adăuga favorite" ON favorites
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Utilizatorii pot șterge propriile favorite" ON favorites
  FOR DELETE USING (auth.uid() = user_id);

-- Creează tabela messages dacă nu există
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

-- Enable RLS pentru messages
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;

-- Politici pentru messages
DROP POLICY IF EXISTS "Utilizatorii pot vedea mesajele lor" ON messages;
DROP POLICY IF EXISTS "Utilizatorii pot trimite mesaje" ON messages;

CREATE POLICY "Utilizatorii pot vedea mesajele lor" ON messages
  FOR SELECT USING (auth.uid() = sender_id OR auth.uid() = receiver_id);

CREATE POLICY "Utilizatorii pot trimite mesaje" ON messages
  FOR INSERT WITH CHECK (auth.uid() = sender_id);

-- Creează tabela reviews dacă nu există
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

-- Enable RLS pentru reviews
ALTER TABLE reviews ENABLE ROW LEVEL SECURITY;

-- Politici pentru reviews
DROP POLICY IF EXISTS "Recenziile sunt vizibile pentru toți" ON reviews;
DROP POLICY IF EXISTS "Utilizatorii pot lăsa recenzii" ON reviews;

CREATE POLICY "Recenziile sunt vizibile pentru toți" ON reviews
  FOR SELECT USING (true);

CREATE POLICY "Utilizatorii pot lăsa recenzii" ON reviews
  FOR INSERT WITH CHECK (auth.uid() = reviewer_id);

-- Funcție pentru actualizarea timestamp-urilor
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ language 'plpgsql';

-- Trigger pentru actualizarea automată a updated_at pentru listings
DROP TRIGGER IF EXISTS update_listings_updated_at ON listings;
CREATE TRIGGER update_listings_updated_at BEFORE UPDATE ON listings
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Indexuri pentru performanță
CREATE INDEX IF NOT EXISTS idx_listings_seller_id ON listings(seller_id);
CREATE INDEX IF NOT EXISTS idx_listings_category ON listings(category);
CREATE INDEX IF NOT EXISTS idx_listings_brand ON listings(brand);
CREATE INDEX IF NOT EXISTS idx_listings_price ON listings(price);
CREATE INDEX IF NOT EXISTS idx_listings_year ON listings(year);
CREATE INDEX IF NOT EXISTS idx_listings_location ON listings(location);
CREATE INDEX IF NOT EXISTS idx_listings_status ON listings(status);
CREATE INDEX IF NOT EXISTS idx_listings_created_at ON listings(created_at);
CREATE INDEX IF NOT EXISTS idx_favorites_user_id ON favorites(user_id);
CREATE INDEX IF NOT EXISTS idx_favorites_listing_id ON favorites(listing_id);
CREATE INDEX IF NOT EXISTS idx_messages_receiver_id ON messages(receiver_id);
CREATE INDEX IF NOT EXISTS idx_messages_sender_id ON messages(sender_id);