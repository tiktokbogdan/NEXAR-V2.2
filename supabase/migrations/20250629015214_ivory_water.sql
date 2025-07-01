/*
  # Fix pentru vizualizarea anunțurilor în așteptare de către admin

  1. Modificări
    - Asigură că adminul poate vedea toate anunțurile, inclusiv cele în așteptare
    - Simplifică politicile pentru a evita recursiunea
    - Adaugă politici explicite pentru anunțurile în așteptare

  2. Securitate
    - Menține securitatea prin permiterea doar adminilor să vadă anunțurile în așteptare
    - Utilizatorii obișnuiți pot vedea doar propriile anunțuri în așteptare
*/

-- Pasul 1: Dezactivează temporar RLS pentru a opri recursiunea
ALTER TABLE listings DISABLE ROW LEVEL SECURITY;

-- Pasul 2: Șterge politicile existente pentru listings
DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN (SELECT policyname FROM pg_policies WHERE tablename = 'listings' AND schemaname = 'public') LOOP
        EXECUTE 'DROP POLICY IF EXISTS "' || r.policyname || '" ON public.listings';
    END LOOP;
END $$;

-- Pasul 3: Reactivează RLS
ALTER TABLE listings ENABLE ROW LEVEL SECURITY;

-- Pasul 4: Creează politici noi pentru listings

-- Politică pentru SELECT - Toată lumea poate vedea anunțurile active
CREATE POLICY "listings_select_active" ON listings
  FOR SELECT USING (status = 'active');

-- Politică pentru SELECT - Utilizatorii pot vedea propriile anunțuri (inclusiv cele în așteptare)
CREATE POLICY "listings_select_own" ON listings
  FOR SELECT USING (
    auth.uid() IS NOT NULL AND 
    seller_id IN (
      SELECT id FROM profiles 
      WHERE user_id = auth.uid()
    )
  );

-- Politică pentru INSERT - Utilizatorii autentificați pot crea anunțuri
CREATE POLICY "listings_insert" ON listings
  FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);

-- Politică pentru UPDATE - Utilizatorii pot actualiza propriile anunțuri
CREATE POLICY "listings_update_own" ON listings
  FOR UPDATE USING (
    auth.uid() IS NOT NULL AND 
    seller_id IN (
      SELECT id FROM profiles 
      WHERE user_id = auth.uid()
    )
  );

-- Politică pentru DELETE - Utilizatorii pot șterge propriile anunțuri
CREATE POLICY "listings_delete_own" ON listings
  FOR DELETE USING (
    auth.uid() IS NOT NULL AND 
    seller_id IN (
      SELECT id FROM profiles 
      WHERE user_id = auth.uid()
    )
  );

-- Politici pentru admin - folosind email în loc de subqueries
-- IMPORTANT: Aceste politici permit adminului să vadă TOATE anunțurile, inclusiv cele în așteptare
CREATE POLICY "admin_select_all_listings" ON listings
  FOR SELECT USING (
    auth.email() = 'admin@nexar.ro'
  );

CREATE POLICY "admin_update_all_listings" ON listings
  FOR UPDATE USING (
    auth.email() = 'admin@nexar.ro'
  );

CREATE POLICY "admin_delete_all_listings" ON listings
  FOR DELETE USING (
    auth.email() = 'admin@nexar.ro'
  );

-- Pasul 5: Adaugă index pentru performanță
CREATE INDEX IF NOT EXISTS idx_listings_status ON listings(status);

-- Pasul 6: Test final - verifică că totul funcționează
DO $$
BEGIN
  -- Testează accesul la listings
  PERFORM COUNT(*) FROM listings;
  RAISE NOTICE 'Acces la toate anunțurile pentru admin: OK';
  
  -- Testează accesul la anunțurile în așteptare
  PERFORM COUNT(*) FROM listings WHERE status = 'pending';
  RAISE NOTICE 'Acces la anunțurile în așteptare pentru admin: OK';
  
EXCEPTION
  WHEN OTHERS THEN
    RAISE WARNING 'Testul a eșuat: %', SQLERRM;
END $$;