/*
  # Fix infinite recursion in profiles RLS policy

  1. Problem
    - The policy "Adminii pot vedea toate profilurile" on profiles table causes infinite recursion
    - It tries to query profiles table from within a profiles table policy
    
  2. Solution
    - Remove the problematic policy that causes infinite recursion
    - Keep other admin policies for listings table which work correctly
*/

-- Remove the problematic policy that causes infinite recursion
DROP POLICY IF EXISTS "Adminii pot vedea toate profilurile" ON profiles;