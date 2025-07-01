-- 🚨 CRITICAL FIX - Email Confirmation Links and Error Handling
-- This migration fixes issues with email confirmation links and redirects

-- Step 1: Configure proper email confirmation settings
UPDATE auth.config
SET 
  site_url = 'http://localhost:3000',
  additional_redirect_urls = ARRAY[
    'https://nexar-motorcycle-marketplace.netlify.app/auth/confirm',
    'https://nexar-motorcycle-marketplace.netlify.app/auth/callback',
    'https://nexar-motorcycle-marketplace.netlify.app/auth/reset-password',
    'http://localhost:3000/auth/confirm',
    'http://localhost:3000/auth/callback',
    'http://localhost:3000/auth/reset-password',
    'http://localhost:5173/auth/confirm',
    'http://localhost:5173/auth/callback',
    'http://localhost:5173/auth/reset-password'
  ],
  email_confirm_changes = true,
  enable_confirmations = true,
  mailer_autoconfirm = false;

-- Step 2: Update email templates to use the correct redirect URLs and Romanian language
UPDATE auth.templates
SET subject = 'Confirmă-ți contul Nexar',
    template = '
<h2>Confirmă-ți contul Nexar</h2>

<p>Salut!</p>
<p>Bine ai venit în comunitatea Nexar - marketplace-ul premium pentru motociclete din România.</p>
<p>Apasă pe butonul de mai jos pentru a-ți confirma contul:</p>

<table border="0" cellpadding="0" cellspacing="0" style="margin-top: 24px; margin-bottom: 24px">
  <tr>
    <td align="center" bgcolor="#d73a30" style="border-radius: 4px;">
      <a href="{{ .ConfirmationURL }}" target="_blank" style="padding: 12px 24px; border-radius: 4px; color: white; text-decoration: none; display: inline-block; font-weight: bold; font-size: 16px;">
        Confirmă Email-ul
      </a>
    </td>
  </tr>
</table>

<p>Dacă nu te-ai înregistrat pe Nexar, te rugăm să ignori acest email.</p>

<p>Mulțumim,<br>Echipa Nexar</p>
'
WHERE template_type = 'confirmation';

-- Step 3: Update password reset email template
UPDATE auth.templates
SET subject = 'Resetare parolă Nexar',
    template = '
<h2>Resetare parolă Nexar</h2>

<p>Salut!</p>
<p>Ai solicitat resetarea parolei pentru contul tău Nexar.</p>
<p>Apasă pe butonul de mai jos pentru a-ți reseta parola:</p>

<table border="0" cellpadding="0" cellspacing="0" style="margin-top: 24px; margin-bottom: 24px">
  <tr>
    <td align="center" bgcolor="#d73a30" style="border-radius: 4px;">
      <a href="{{ .ConfirmationURL }}" target="_blank" style="padding: 12px 24px; border-radius: 4px; color: white; text-decoration: none; display: inline-block; font-weight: bold; font-size: 16px;">
        Resetează Parola
      </a>
    </td>
  </tr>
</table>

<p>Dacă nu ai solicitat resetarea parolei, te rugăm să ignori acest email.</p>

<p>Mulțumim,<br>Echipa Nexar</p>
'
WHERE template_type = 'recovery';

-- Step 4: Create a function to handle profile creation that bypasses RLS
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
END;
$$;

-- Step 5: Update handle_new_user function to use RLS bypass
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

-- Step 6: Recreate the trigger
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- Step 7: Fix auth settings to properly handle OTP expiration
UPDATE auth.config
SET 
  jwt_expiry = 3600,
  enable_refresh_token_rotation = true,
  refresh_token_reuse_interval = 10,
  enable_signup = true,
  enable_anonymous_sign_ins = false,
  minimum_password_length = 8;

-- Step 8: Create a function to fix OTP issues
CREATE OR REPLACE FUNCTION fix_expired_otp()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Extend expiry time for existing OTPs
  UPDATE auth.flow_state
  SET created_at = now()
  WHERE now() - created_at > interval '1 hour';
  
  RAISE NOTICE 'OTP expiry times have been reset';
END;
$$;

-- Step 9: Create a function to manually confirm a user's email
CREATE OR REPLACE FUNCTION admin_confirm_user_email(user_email text)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  user_id uuid;
BEGIN
  -- Find the user ID
  SELECT id INTO user_id FROM auth.users WHERE email = user_email;
  
  IF user_id IS NULL THEN
    RAISE EXCEPTION 'User with email % not found', user_email;
  END IF;
  
  -- Update the user's email_confirmed_at
  UPDATE auth.users
  SET email_confirmed_at = now(),
      updated_at = now()
  WHERE id = user_id;
  
  -- Update the user's profile to mark as verified
  UPDATE profiles
  SET verified = true
  WHERE user_id = user_id;
  
  RETURN true;
EXCEPTION
  WHEN OTHERS THEN
    RAISE WARNING 'Failed to confirm email for user %: %', user_email, SQLERRM;
    RETURN false;
END;
$$;

-- Step 10: Fix existing users' profiles
DO $$
DECLARE
    u RECORD;
BEGIN
    FOR u IN (
        SELECT id, email FROM auth.users
        WHERE id NOT IN (SELECT user_id FROM profiles)
    ) LOOP
        PERFORM create_profile_bypass_rls(
            u.id,
            split_part(u.email, '@', 1),
            u.email,
            '',
            '',
            'individual',
            false,
            u.email = 'admin@nexar.ro'
        );
        RAISE NOTICE 'Created missing profile for user %', u.email;
    END LOOP;
END $$;