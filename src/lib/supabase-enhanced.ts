import { createClient } from '@supabase/supabase-js'
import { connectionFixer } from './supabase-connection-fix'

// Enhanced Supabase client with better error handling and retry logic
const supabaseUrl = 'https://tidnmzsivsthwwcfdzyo.supabase.co'
const supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRpZG5tenNpdnN0aHd3Y2ZkenlvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTA3MjE5NTgsImV4cCI6MjA2NjI5Nzk1OH0.Sr1gSZ2qtoff7gmulkT8uIzB8eL7gqKUUNVj82OqHog'

// Create enhanced client with retry logic
export const supabaseEnhanced = createClient(supabaseUrl, supabaseAnonKey, {
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
  }
})

// Enhanced error handling wrapper
export const withRetry = async <T>(
  operation: () => Promise<T>,
  maxRetries: number = 3,
  delay: number = 1000
): Promise<T> => {
  let lastError: any

  for (let attempt = 1; attempt <= maxRetries; attempt++) {
    try {
      console.log(`🔄 Attempt ${attempt}/${maxRetries}`)
      const result = await operation()
      console.log(`✅ Operation succeeded on attempt ${attempt}`)
      return result
    } catch (error: any) {
      lastError = error
      console.error(`❌ Attempt ${attempt} failed:`, error.message)

      // If it's a network error, try to diagnose and fix
      if (error.message?.includes('NetworkError') || error.message?.includes('fetch')) {
        console.log('🔍 Network error detected, running diagnosis...')
        const diagnosis = await connectionFixer.runComprehensiveDiagnosis()
        
        if (!diagnosis.overall) {
          console.log('⚠️ Connection issues detected, attempting fix...')
          await connectionFixer.attemptAutomaticFixes()
        }
      }

      if (attempt < maxRetries) {
        console.log(`⏳ Waiting ${delay}ms before retry...`)
        await new Promise(resolve => setTimeout(resolve, delay))
        delay *= 1.5 // Exponential backoff
      }
    }
  }

  throw lastError
}

// Enhanced connection check
export const checkConnection = async () => {
  try {
    console.log('🔍 Checking Supabase connection...')
    
    const result = await withRetry(async () => {
      const { data, error } = await supabaseEnhanced
        .from('profiles')
        .select('count', { count: 'exact', head: true })
      
      if (error) {
        throw error
      }
      
      return data
    })

    console.log('✅ Connection check successful')
    return {
      success: true,
      message: 'Connected to Supabase successfully',
      data: result
    }
  } catch (error: any) {
    console.error('❌ Connection check failed:', error)
    
    // Provide detailed error information
    const errorInfo = {
      success: false,
      error: error.message,
      guidance: getErrorGuidance(error),
      troubleshooting: getTroubleshootingSteps(error)
    }

    return errorInfo
  }
}

// Get specific guidance based on error type
const getErrorGuidance = (error: any): string => {
  const message = error.message?.toLowerCase() || ''
  
  if (message.includes('networkerror') || message.includes('fetch')) {
    return 'Network connectivity issue - check if Supabase project is active and CORS is configured'
  }
  
  if (message.includes('cors')) {
    return 'CORS configuration issue - add your domain to allowed origins in Supabase'
  }
  
  if (message.includes('unauthorized') || message.includes('401')) {
    return 'Authentication issue - verify your API keys in Supabase Dashboard'
  }
  
  if (message.includes('forbidden') || message.includes('403')) {
    return 'Permission issue - check RLS policies and table permissions'
  }
  
  if (message.includes('not found') || message.includes('404')) {
    return 'Resource not found - verify table names and project URL'
  }
  
  return 'Unknown error - check Supabase Dashboard for project status'
}

// Get troubleshooting steps based on error
const getTroubleshootingSteps = (error: any): string[] => {
  const message = error.message?.toLowerCase() || ''
  const steps: string[] = []
  
  if (message.includes('networkerror') || message.includes('fetch')) {
    steps.push('1. Check if your Supabase project is active (not paused)')
    steps.push('2. Verify project URL matches: https://tidnmzsivsthwwcfdzyo.supabase.co')
    steps.push('3. Add your domain to CORS allowed origins')
    steps.push('4. Check your internet connection')
  }
  
  if (message.includes('cors')) {
    steps.push('1. Go to Supabase Dashboard → Settings → API → CORS')
    steps.push(`2. Add ${window.location.origin} to allowed origins`)
    steps.push('3. Save changes and wait a few minutes')
  }
  
  if (message.includes('unauthorized')) {
    steps.push('1. Go to Supabase Dashboard → Settings → API')
    steps.push('2. Copy the correct anon public key')
    steps.push('3. Update your environment variables')
  }
  
  if (steps.length === 0) {
    steps.push('1. Check Supabase Dashboard for any alerts')
    steps.push('2. Verify project is not paused or suspended')
    steps.push('3. Try refreshing the page')
  }
  
  return steps
}

// Enhanced listings functions with retry logic
export const enhancedListings = {
  getAll: async (filters?: any) => {
    return await withRetry(async () => {
      console.log('🔍 Fetching listings with enhanced client...')
      
      let query = supabaseEnhanced
        .from('listings')
        .select('*')
        .eq('status', 'active')
        .order('created_at', { ascending: false })

      if (filters) {
        if (filters.category) query = query.eq('category', filters.category.toLowerCase())
        if (filters.brand) query = query.eq('brand', filters.brand)
        if (filters.priceMin) query = query.gte('price', filters.priceMin)
        if (filters.priceMax) query = query.lte('price', filters.priceMax)
        if (filters.yearMin) query = query.gte('year', filters.yearMin)
        if (filters.yearMax) query = query.lte('year', filters.yearMax)
        if (filters.location) query = query.ilike('location', `%${filters.location}%`)
        if (filters.sellerType) query = query.eq('seller_type', filters.sellerType)
        if (filters.condition) query = query.eq('condition', filters.condition)
        if (filters.fuel) query = query.eq('fuel_type', filters.fuel)
        if (filters.transmission) query = query.eq('transmission', filters.transmission)
        if (filters.engineMin) query = query.gte('engine_capacity', filters.engineMin)
        if (filters.engineMax) query = query.lte('engine_capacity', filters.engineMax)
        if (filters.mileageMax) query = query.lte('mileage', filters.mileageMax)
      }

      const { data, error } = await query
      
      if (error) {
        throw error
      }
      
      console.log(`✅ Successfully fetched ${data?.length || 0} listings`)
      return { data, error: null }
    })
  }
}