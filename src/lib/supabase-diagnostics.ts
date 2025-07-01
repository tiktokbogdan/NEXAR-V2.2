// Supabase Connection Diagnostics and Fix Utility
import { createClient } from '@supabase/supabase-js'

// Test different connection configurations
export const diagnoseSupabaseConnection = async () => {
  console.log('🔍 Starting Supabase connection diagnostics...')
  
  const results = {
    credentialsTest: false,
    corsTest: false,
    apiTest: false,
    storageTest: false,
    authTest: false,
    recommendations: [] as string[]
  }

  // Current credentials from your config
  const supabaseUrl = 'https://tidnmzsivsthwwcfdzyo.supabase.co'
  const supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRpZG5tenNpdnN0aHd3Y2ZkenlvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTA3MjE5NTgsImV4cCI6MjA2NjI5Nzk1OH0.Sr1gSZ2qtoff7gmulkT8uIzB8eL7gqKUUNVj82OqHog'

  // Test 1: Basic URL and Key Format
  console.log('📋 Test 1: Checking credentials format...')
  try {
    if (!supabaseUrl || !supabaseUrl.includes('supabase.co')) {
      results.recommendations.push('❌ Invalid Supabase URL format')
    } else if (!supabaseAnonKey || supabaseAnonKey.length < 100) {
      results.recommendations.push('❌ Invalid Supabase anon key format')
    } else {
      results.credentialsTest = true
      console.log('✅ Credentials format looks correct')
    }
  } catch (error) {
    results.recommendations.push('❌ Error validating credentials format')
  }

  // Test 2: Basic Network Connectivity
  console.log('🌐 Test 2: Testing basic network connectivity...')
  try {
    const response = await fetch(`${supabaseUrl}/rest/v1/`, {
      method: 'HEAD',
      headers: {
        'apikey': supabaseAnonKey,
        'Authorization': `Bearer ${supabaseAnonKey}`
      }
    })
    
    if (response.ok) {
      results.corsTest = true
      console.log('✅ Basic network connectivity successful')
    } else {
      console.log('❌ Network connectivity failed:', response.status, response.statusText)
      results.recommendations.push(`❌ Network error: ${response.status} ${response.statusText}`)
    }
  } catch (error: any) {
    console.log('❌ Network connectivity failed:', error.message)
    results.recommendations.push(`❌ Network error: ${error.message}`)
    
    if (error.message.includes('CORS')) {
      results.recommendations.push('🔧 CORS issue detected - check Supabase Dashboard CORS settings')
    }
  }

  // Test 3: API Endpoint Test
  console.log('🔌 Test 3: Testing API endpoints...')
  try {
    const testClient = createClient(supabaseUrl, supabaseAnonKey, {
      auth: {
        autoRefreshToken: false,
        persistSession: false
      }
    })

    const { data, error } = await testClient
      .from('profiles')
      .select('count', { count: 'exact', head: true })

    if (!error) {
      results.apiTest = true
      console.log('✅ API endpoint test successful')
    } else {
      console.log('❌ API endpoint test failed:', error.message)
      results.recommendations.push(`❌ API error: ${error.message}`)
    }
  } catch (error: any) {
    console.log('❌ API endpoint test failed:', error.message)
    results.recommendations.push(`❌ API error: ${error.message}`)
  }

  // Test 4: Storage Test
  console.log('📦 Test 4: Testing storage access...')
  try {
    const testClient = createClient(supabaseUrl, supabaseAnonKey)
    const { data: buckets, error } = await testClient.storage.listBuckets()
    
    if (!error) {
      results.storageTest = true
      console.log('✅ Storage access successful')
      console.log('📁 Available buckets:', buckets?.map(b => b.name).join(', ') || 'none')
    } else {
      console.log('❌ Storage access failed:', error.message)
      results.recommendations.push(`❌ Storage error: ${error.message}`)
    }
  } catch (error: any) {
    console.log('❌ Storage access failed:', error.message)
    results.recommendations.push(`❌ Storage error: ${error.message}`)
  }

  // Test 5: Auth Test
  console.log('🔐 Test 5: Testing auth endpoints...')
  try {
    const testClient = createClient(supabaseUrl, supabaseAnonKey)
    const { data, error } = await testClient.auth.getSession()
    
    if (!error) {
      results.authTest = true
      console.log('✅ Auth endpoint test successful')
    } else {
      console.log('❌ Auth endpoint test failed:', error.message)
      results.recommendations.push(`❌ Auth error: ${error.message}`)
    }
  } catch (error: any) {
    console.log('❌ Auth endpoint test failed:', error.message)
    results.recommendations.push(`❌ Auth error: ${error.message}`)
  }

  // Generate final recommendations
  if (results.recommendations.length === 0) {
    results.recommendations.push('✅ All tests passed! Connection should be working.')
  } else {
    results.recommendations.unshift('🔧 Issues found. Please check the following:')
    results.recommendations.push('')
    results.recommendations.push('📋 Steps to fix:')
    results.recommendations.push('1. Go to your Supabase Dashboard (https://supabase.com/dashboard)')
    results.recommendations.push('2. Select your project: tidnmzsivsthwwcfdzyo')
    results.recommendations.push('3. Go to Settings → API')
    results.recommendations.push('4. Verify Project URL and anon public key match your code')
    results.recommendations.push('5. Go to Settings → API → CORS')
    results.recommendations.push('6. Add http://localhost:3000 to Allowed Origins')
    results.recommendations.push('7. Make sure your project is not paused')
    results.recommendations.push('8. Check if you have any RLS policies blocking access')
  }

  console.log('📊 Diagnostic Results:', results)
  return results
}

// Alternative connection with better error handling
export const createRobustSupabaseClient = (url: string, key: string) => {
  return createClient(url, key, {
    auth: {
      autoRefreshToken: true,
      persistSession: true,
      detectSessionInUrl: true,
      flowType: 'pkce'
    },
    global: {
      headers: {
        'X-Client-Info': 'nexar-app'
      }
    },
    db: {
      schema: 'public'
    },
    realtime: {
      params: {
        eventsPerSecond: 2
      }
    }
  })
}

// Test connection with retry logic
export const testConnectionWithRetry = async (maxRetries = 3) => {
  const supabaseUrl = 'https://tidnmzsivsthwwcfdzyo.supabase.co'
  const supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRpZG5tenNpdnN0aHd3Y2ZkenlvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTA3MjE5NTgsImV4cCI6MjA2NjI5Nzk1OH0.Sr1gSZ2qtoff7gmulkT8uIzB8eL7gqKUUNVj82OqHog'

  for (let attempt = 1; attempt <= maxRetries; attempt++) {
    console.log(`🔄 Connection attempt ${attempt}/${maxRetries}...`)
    
    try {
      const client = createRobustSupabaseClient(supabaseUrl, supabaseAnonKey)
      
      const { data, error } = await client
        .from('profiles')
        .select('count', { count: 'exact', head: true })
      
      if (!error) {
        console.log('✅ Connection successful!')
        return { success: true, client, attempt }
      } else {
        console.log(`❌ Attempt ${attempt} failed:`, error.message)
        if (attempt === maxRetries) {
          throw error
        }
      }
    } catch (error: any) {
      console.log(`❌ Attempt ${attempt} failed:`, error.message)
      if (attempt === maxRetries) {
        throw error
      }
      
      // Wait before retry (exponential backoff)
      await new Promise(resolve => setTimeout(resolve, 1000 * attempt))
    }
  }
  
  return { success: false, client: null, attempt: maxRetries }
}