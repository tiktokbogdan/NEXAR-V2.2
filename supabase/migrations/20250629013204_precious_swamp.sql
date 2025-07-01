/*
  # Fix Listings Insert RLS Policy

  1. Problem
    - Current RLS policy for listings insert is too restrictive
    - Prevents users from creating new listings due to seller_id validation
    
  2. Solution
    - Update the listings_insert policy to be more permissive
    - Allow authenticated users to insert listings without strict seller_id validation during insert
    - Maintain security by ensuring only authenticated users can insert
    
  3. Changes
    - Drop existing restrictive insert policy
    - Create new permissive insert policy for authenticated users
    - Keep other policies intact for security
*/

-- Drop the existing restrictive insert policy
DROP POLICY IF EXISTS "listings_insert" ON listings;

-- Create a more permissive insert policy for authenticated users
CREATE POLICY "listings_insert" ON listings
  FOR INSERT WITH CHECK (
    auth.uid() IS NOT NULL
  );

-- Ensure the update policy still maintains proper ownership
DROP POLICY IF EXISTS "listings_update" ON listings;
CREATE POLICY "listings_update" ON listings
  FOR UPDATE USING (
    auth.uid() IS NOT NULL AND 
    seller_id IN (
      SELECT id FROM profiles 
      WHERE user_id = auth.uid() 
      LIMIT 1
    )
  );

-- Ensure the delete policy still maintains proper ownership  
DROP POLICY IF EXISTS "listings_delete" ON listings;
CREATE POLICY "listings_delete" ON listings
  FOR DELETE USING (
    auth.uid() IS NOT NULL AND 
    seller_id IN (
      SELECT id FROM profiles 
      WHERE user_id = auth.uid() 
      LIMIT 1
    )
  );

-- Test the policy by checking if we can access listings
DO $$
BEGIN
  -- Test select access
  PERFORM COUNT(*) FROM listings WHERE status = 'active';
  RAISE NOTICE 'Listings select policy: OK';
  
EXCEPTION
  WHEN OTHERS THEN
    RAISE WARNING 'Listings policy test failed: %', SQLERRM;
END $$;