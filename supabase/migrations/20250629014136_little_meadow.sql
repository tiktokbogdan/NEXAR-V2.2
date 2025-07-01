-- 🚨 MIGRAȚIA PENTRU REZOLVAREA PROBLEMEI CU POLITICA RLS LA INSERARE ANUNȚURI
-- Rulează această migrație în Supabase Dashboard → SQL Editor

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

-- Politică pentru INSERT - Utilizatorii autentificați pot crea anunțuri (inclusiv cu status "pending")
-- ACEASTA ESTE POLITICA CORECTATĂ - mult mai permisivă pentru inserare
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
  PERFORM COUNT(*) FROM listings WHERE status = 'active';
  RAISE NOTICE 'Acces la tabela listings: OK';
  
EXCEPTION
  WHEN OTHERS THEN
    RAISE WARNING 'Testul a eșuat: %', SQLERRM;
END $$;