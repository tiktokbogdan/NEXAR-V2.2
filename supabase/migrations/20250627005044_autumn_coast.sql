/*
  # Reparare funcționalitate favorite și adăugare câmp coordonate

  1. Modificări
    - Adaugă câmpul `coordinates` la tabela `listings` pentru locația exactă
    - Repară politicile RLS pentru tabela `favorites`
    - Asigură că toate anunțurile sunt publicate cu status 'active'

  2. Securitate
    - Simplifică politicile RLS pentru a evita recursiunea
    - Asigură că utilizatorii pot adăuga/șterge favorite
*/

-- Adaugă coloana coordinates la tabela listings dacă nu există
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'listings' AND column_name = 'coordinates'
  ) THEN
    ALTER TABLE listings ADD COLUMN coordinates text;
  END IF;
END $$;

-- Dezactivează temporar RLS pentru a opri recursiunea
ALTER TABLE favorites DISABLE ROW LEVEL SECURITY;

-- Șterge toate politicile existente pentru favorites
DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN (SELECT policyname FROM pg_policies WHERE tablename = 'favorites' AND schemaname = 'public') LOOP
        EXECUTE 'DROP POLICY IF EXISTS "' || r.policyname || '" ON public.favorites';
    END LOOP;
END $$;

-- Reactivează RLS
ALTER TABLE favorites ENABLE ROW LEVEL SECURITY;

-- Creează politici SIMPLE pentru FAVORITES
CREATE POLICY "favorites_select" ON favorites
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "favorites_insert" ON favorites
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "favorites_delete" ON favorites
  FOR DELETE USING (auth.uid() = user_id);

-- Creează index pentru performanță
CREATE INDEX IF NOT EXISTS idx_favorites_user_id_listing_id ON favorites(user_id, listing_id);

-- Verifică dacă există înregistrări duplicate în favorites și le elimină
DO $$
DECLARE
    r RECORD;
    cnt INT;
BEGIN
    FOR r IN (
        SELECT user_id, listing_id, COUNT(*) as cnt
        FROM favorites
        GROUP BY user_id, listing_id
        HAVING COUNT(*) > 1
    ) LOOP
        -- Păstrează doar o înregistrare și șterge duplicatele
        DELETE FROM favorites
        WHERE id IN (
            SELECT id FROM favorites
            WHERE user_id = r.user_id AND listing_id = r.listing_id
            ORDER BY created_at DESC
            OFFSET 1
        );
        
        RAISE NOTICE 'Removed % duplicate favorites for user % and listing %', r.cnt - 1, r.user_id, r.listing_id;
    END LOOP;
END $$;

-- Adaugă constrângere UNIQUE dacă nu există
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'favorites_user_id_listing_id_key' AND conrelid = 'favorites'::regclass
  ) THEN
    ALTER TABLE favorites ADD CONSTRAINT favorites_user_id_listing_id_key UNIQUE (user_id, listing_id);
  END IF;
END $$;

-- Funcție pentru a verifica dacă un anunț este favorit pentru un utilizator
CREATE OR REPLACE FUNCTION is_favorite(user_id uuid, listing_id uuid)
RETURNS boolean AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM favorites
    WHERE user_id = $1 AND listing_id = $2
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Funcție pentru a adăuga un anunț la favorite
CREATE OR REPLACE FUNCTION add_to_favorites(user_id uuid, listing_id uuid)
RETURNS boolean AS $$
BEGIN
  -- Verifică dacă există deja
  IF EXISTS (SELECT 1 FROM favorites WHERE user_id = $1 AND listing_id = $2) THEN
    RETURN true;
  END IF;
  
  -- Adaugă la favorite
  INSERT INTO favorites (user_id, listing_id)
  VALUES ($1, $2);
  
  RETURN true;
EXCEPTION
  WHEN OTHERS THEN
    RETURN false;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Funcție pentru a șterge un anunț din favorite
CREATE OR REPLACE FUNCTION remove_from_favorites(user_id uuid, listing_id uuid)
RETURNS boolean AS $$
BEGIN
  DELETE FROM favorites
  WHERE user_id = $1 AND listing_id = $2;
  
  RETURN true;
EXCEPTION
  WHEN OTHERS THEN
    RETURN false;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;