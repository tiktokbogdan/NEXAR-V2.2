/*
  # Fix Profile Creation RLS Issue

  1. Changes
    - Add database trigger to automatically create profiles when users sign up
    - Remove INSERT policy for profiles table since creation will be server-side
    - Add function to handle new user profile creation

  2. Security
    - Profile creation handled server-side via trigger
    - Maintains RLS for other operations
*/

-- Function to handle new user profile creation
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

-- Trigger to automatically create profile when user signs up
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- Remove the INSERT policy for profiles since creation is now server-side
DROP POLICY IF EXISTS "Utilizatorii pot să-și creeze propriul profil" ON profiles;

-- Keep other policies intact
-- SELECT policy remains: "Profiles sunt vizibile pentru toți"
-- UPDATE policy remains: "Utilizatorii pot să-și actualizeze propriul profil"