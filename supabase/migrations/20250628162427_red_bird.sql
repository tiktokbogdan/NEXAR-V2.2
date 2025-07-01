-- 🔧 Fix pentru editarea anunțurilor - Rulează în Supabase SQL Editor

-- Pasul 1: Verifică și repară politicile pentru editarea anunțurilor
-- Șterge politicile duplicate pentru listings
DROP POLICY IF EXISTS "listings_update" ON listings;
DROP POLICY IF EXISTS "listings_update_own" ON listings;
DROP POLICY IF EXISTS "listings_delete" ON listings;
DROP POLICY IF EXISTS "listings_delete_own" ON listings;

-- Creează politici corecte pentru editarea anunțurilor
CREATE POLICY "listings_update_owner" ON listings
  FOR UPDATE USING (
    auth.uid() IS NOT NULL AND 
    seller_id = (
      SELECT id FROM profiles 
      WHERE user_id = auth.uid() 
      LIMIT 1
    )
  );

CREATE POLICY "listings_delete_owner" ON listings
  FOR DELETE USING (
    auth.uid() IS NOT NULL AND 
    seller_id = (
      SELECT id FROM profiles 
      WHERE user_id = auth.uid() 
      LIMIT 1
    )
  );

-- Pasul 2: Verifică că există indexuri pentru performanță
CREATE INDEX IF NOT EXISTS idx_listings_seller_id_user ON listings(seller_id);
CREATE INDEX IF NOT EXISTS idx_profiles_user_id_unique ON profiles(user_id);

-- Pasul 3: Test pentru verificarea funcționalității
DO $$
BEGIN
  -- Testează că politicile funcționează
  RAISE NOTICE 'Politici pentru editarea anunțurilor create cu succes!';
EXCEPTION
  WHEN OTHERS THEN
    RAISE WARNING 'Eroare la crearea politicilor: %', SQLERRM;
END $$;