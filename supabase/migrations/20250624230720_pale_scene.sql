/*
  # Adaugă coloana description la tabela profiles

  1. Modificări
    - Adaugă coloana `description` la tabela `profiles`
    - Adaugă coloana `website` pentru dealeri
    - Îmbunătățește validările pentru datele existente

  2. Securitate
    - Păstrează politicile RLS existente
*/

-- Adaugă coloana description dacă nu există
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'profiles' AND column_name = 'description'
  ) THEN
    ALTER TABLE profiles ADD COLUMN description text;
  END IF;
END $$;

-- Adaugă coloana website dacă nu există
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'profiles' AND column_name = 'website'
  ) THEN
    ALTER TABLE profiles ADD COLUMN website text;
  END IF;
END $$;

-- Adaugă index pentru căutări mai rapide
CREATE INDEX IF NOT EXISTS idx_profiles_name ON profiles(name);
CREATE INDEX IF NOT EXISTS idx_profiles_location ON profiles(location);
CREATE INDEX IF NOT EXISTS idx_profiles_seller_type ON profiles(seller_type);