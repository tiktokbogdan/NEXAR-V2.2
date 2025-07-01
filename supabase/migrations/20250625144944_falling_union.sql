-- Creează funcția pentru verificarea rolului de admin
CREATE OR REPLACE FUNCTION is_admin(user_email text)
RETURNS boolean AS $$
BEGIN
  RETURN user_email = 'admin@nexar.ro';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Adaugă coloana is_admin la tabela profiles dacă nu există
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'profiles' AND column_name = 'is_admin'
  ) THEN
    ALTER TABLE profiles ADD COLUMN is_admin boolean DEFAULT false;
  END IF;
END $$;

-- Creează funcția pentru setarea automată a admin-ului
CREATE OR REPLACE FUNCTION handle_admin_user()
RETURNS TRIGGER AS $$
BEGIN
  -- Dacă email-ul este admin@nexar.ro, setează is_admin = true
  IF NEW.email = 'admin@nexar.ro' THEN
    NEW.is_admin = true;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Creează trigger-ul pentru setarea automată a admin-ului
DROP TRIGGER IF EXISTS set_admin_role ON profiles;
CREATE TRIGGER set_admin_role
  BEFORE INSERT OR UPDATE ON profiles
  FOR EACH ROW EXECUTE FUNCTION handle_admin_user();

-- Actualizează profilul existent dacă există deja admin@nexar.ro
UPDATE profiles 
SET is_admin = true 
WHERE email = 'admin@nexar.ro';

-- Adaugă politici RLS pentru admin
CREATE POLICY "Adminii pot vedea toate anunțurile" ON listings
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM profiles 
      WHERE user_id = auth.uid() AND is_admin = true
    )
  );

CREATE POLICY "Adminii pot actualiza orice anunț" ON listings
  FOR UPDATE USING (
    EXISTS (
      SELECT 1 FROM profiles 
      WHERE user_id = auth.uid() AND is_admin = true
    )
  );

CREATE POLICY "Adminii pot șterge orice anunț" ON listings
  FOR DELETE USING (
    EXISTS (
      SELECT 1 FROM profiles 
      WHERE user_id = auth.uid() AND is_admin = true
    )
  );

-- Adaugă politici pentru gestionarea utilizatorilor
CREATE POLICY "Adminii pot vedea toate profilurile" ON profiles
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM profiles p2
      WHERE p2.user_id = auth.uid() AND p2.is_admin = true
    )
  );

-- Index pentru performanță
CREATE INDEX IF NOT EXISTS idx_profiles_is_admin ON profiles(is_admin);