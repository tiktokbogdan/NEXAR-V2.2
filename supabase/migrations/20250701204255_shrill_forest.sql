-- Create or replace the function with correct parameter order
CREATE OR REPLACE FUNCTION create_profile_bypass_rls(
  user_id uuid,
  name text,
  email text,
  phone text DEFAULT '',
  location text DEFAULT '',
  seller_type text DEFAULT 'individual',
  verified boolean DEFAULT false,
  is_admin boolean DEFAULT false
)
RETURNS SETOF profiles
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Temporarily disable RLS for this operation
  SET LOCAL row_level_security = off;
  
  RETURN QUERY
  INSERT INTO profiles (
    user_id,
    name,
    email,
    phone,
    location,
    seller_type,
    verified,
    is_admin
  ) VALUES (
    user_id,
    name,
    email,
    phone,
    location,
    seller_type,
    verified,
    is_admin
  )
  ON CONFLICT (user_id) DO UPDATE
  SET 
    name = EXCLUDED.name,
    email = EXCLUDED.email,
    phone = EXCLUDED.phone,
    location = EXCLUDED.location,
    seller_type = EXCLUDED.seller_type,
    is_admin = EXCLUDED.is_admin,
    updated_at = now()
  RETURNING *;
  
  -- RLS will be automatically re-enabled at the end of the function
EXCEPTION
  WHEN OTHERS THEN
    RAISE WARNING 'Failed to create profile: %', SQLERRM;
    RETURN;
END;
$$;

-- Grant execute permission to all roles
GRANT EXECUTE ON FUNCTION create_profile_bypass_rls(
  uuid, text, text, text, text, text, boolean, boolean
) TO anon, authenticated, service_role;

-- Update handle_new_user function to use the fixed function
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
  profile_result profiles;
BEGIN
  -- Use the RPC function to bypass RLS
  SELECT * INTO profile_result FROM create_profile_bypass_rls(
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'name', 'Utilizator'),
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'phone', ''),
    COALESCE(NEW.raw_user_meta_data->>'location', ''),
    COALESCE(NEW.raw_user_meta_data->>'sellerType', 'individual'),
    false,
    NEW.email = 'admin@nexar.ro'
  );
  
  RETURN NEW;
EXCEPTION
  WHEN OTHERS THEN
    -- If profile creation fails, still allow user creation
    RAISE WARNING 'Failed to create profile for user %: %', NEW.id, SQLERRM;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Fix existing users' profiles
DO $$
DECLARE
    u RECORD;
BEGIN
    -- Temporarily disable RLS for this operation
    SET LOCAL row_level_security = off;
    
    FOR u IN (
        SELECT id, email FROM auth.users
        WHERE id NOT IN (SELECT user_id FROM profiles)
    ) LOOP
        INSERT INTO profiles (
            user_id,
            name,
            email,
            seller_type,
            is_admin
        ) VALUES (
            u.id,
            split_part(u.email, '@', 1),
            u.email,
            'individual',
            u.email = 'admin@nexar.ro'
        );
        RAISE NOTICE 'Created missing profile for user %', u.email;
    END LOOP;
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE WARNING 'Error creating missing profiles: %', SQLERRM;
END $$;