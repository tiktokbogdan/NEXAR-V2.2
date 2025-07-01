/*
  # Rezolvă toate problemele cu RLS și funcționalități

  1. Modificări
    - Simplifică politicile RLS pentru a evita recursiunea
    - Asigură că anunțurile se afișează corect
    - Permite funcționarea favoritelor

  2. Securitate
    - Politici RLS simple și eficiente
    - Fără recursiune în politici
*/

-- Șterge toate politicile existente pentru profiles
DROP POLICY IF EXISTS "Profiles sunt vizibile pentru toți" ON profiles;
DROP POLICY IF EXISTS "Utilizatorii pot să-și actualizeze propriul profil" ON profiles;
DROP POLICY IF EXISTS "Adminii pot vedea toate profilurile" ON profiles;

-- Creează politici simple pentru profiles
CREATE POLICY "Toată lumea poate vedea profilurile" ON profiles
  FOR SELECT USING (true);

CREATE POLICY "Utilizatorii pot actualiza propriul profil" ON profiles
  FOR UPDATE USING (auth.uid() = user_id);

-- Șterge toate politicile existente pentru listings
DROP POLICY IF EXISTS "Toată lumea poate vedea anunțurile active" ON listings;
DROP POLICY IF EXISTS "Utilizatorii autentificați pot crea anunțuri" ON listings;
DROP POLICY IF EXISTS "Utilizatorii pot actualiza propriile anunțuri" ON listings;
DROP POLICY IF EXISTS "Utilizatorii pot șterge propriile anunțuri" ON listings;
DROP POLICY IF EXISTS "Adminii pot vedea toate anunțurile" ON listings;
DROP POLICY IF EXISTS "Adminii pot actualiza orice anunț" ON listings;
DROP POLICY IF EXISTS "Adminii pot șterge orice anunț" ON listings;

-- Creează politici simple pentru listings
CREATE POLICY "Toată lumea poate vedea anunțurile active" ON listings
  FOR SELECT USING (status = 'active');

CREATE POLICY "Utilizatorii autentificați pot crea anunțuri" ON listings
  FOR INSERT WITH CHECK (
    auth.uid() IS NOT NULL AND 
    EXISTS (SELECT 1 FROM profiles WHERE user_id = auth.uid() AND id = seller_id)
  );

CREATE POLICY "Utilizatorii pot actualiza propriile anunțuri" ON listings
  FOR UPDATE USING (
    auth.uid() IS NOT NULL AND 
    EXISTS (SELECT 1 FROM profiles WHERE user_id = auth.uid() AND id = seller_id)
  );

CREATE POLICY "Utilizatorii pot șterge propriile anunțuri" ON listings
  FOR DELETE USING (
    auth.uid() IS NOT NULL AND 
    EXISTS (SELECT 1 FROM profiles WHERE user_id = auth.uid() AND id = seller_id)
  );

-- Politici pentru admin (simple, fără recursiune)
CREATE POLICY "Admin poate vedea toate anunțurile" ON listings
  FOR SELECT USING (
    auth.uid() IS NOT NULL AND 
    auth.email() = 'admin@nexar.ro'
  );

CREATE POLICY "Admin poate actualiza orice anunț" ON listings
  FOR UPDATE USING (
    auth.uid() IS NOT NULL AND 
    auth.email() = 'admin@nexar.ro'
  );

CREATE POLICY "Admin poate șterge orice anunț" ON listings
  FOR DELETE USING (
    auth.uid() IS NOT NULL AND 
    auth.email() = 'admin@nexar.ro'
  );

-- Asigură că politicile pentru favorites sunt corecte
DROP POLICY IF EXISTS "Utilizatorii pot vedea propriile favorite" ON favorites;
DROP POLICY IF EXISTS "Utilizatorii pot adăuga favorite" ON favorites;
DROP POLICY IF EXISTS "Utilizatorii pot șterge propriile favorite" ON favorites;

CREATE POLICY "Utilizatorii pot vedea propriile favorite" ON favorites
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Utilizatorii pot adăuga favorite" ON favorites
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Utilizatorii pot șterge propriile favorite" ON favorites
  FOR DELETE USING (auth.uid() = user_id);