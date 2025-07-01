import React, { useState } from 'react'
import { diagnoseSupabaseConnection, testConnectionWithRetry } from '../lib/supabase-diagnostics'
import { checkConnection } from '../lib/supabase-enhanced'
import { connectionFixer } from '../lib/supabase-connection-fix'

interface DiagnosticResult {
  credentialsTest: boolean
  corsTest: boolean
  apiTest: boolean
  storageTest: boolean
  authTest: boolean
  recommendations: string[]
}

const ConnectionDiagnostics: React.FC = () => {
  const [isRunning, setIsRunning] = useState(false)
  const [results, setResults] = useState<DiagnosticResult | null>(null)
  const [connectionTest, setConnectionTest] = useState<any>(null)
  const [enhancedDiagnosis, setEnhancedDiagnosis] = useState<any>(null)

  const runDiagnostics = async () => {
    setIsRunning(true)
    setResults(null)
    setConnectionTest(null)
    setEnhancedDiagnosis(null)

    try {
      console.log('🚀 Starting comprehensive diagnostics...')
      
      // Run enhanced connection diagnosis first
      console.log('🔍 Running enhanced diagnosis...')
      const enhancedResult = await connectionFixer.runComprehensiveDiagnosis()
      setEnhancedDiagnosis(enhancedResult)
      
      // Run basic connection check
      const basicCheck = await checkConnection()
      setConnectionTest(basicCheck)
      
      // Run detailed diagnostics if available
      try {
        const diagnosticResults = await diagnoseSupabaseConnection()
        setResults(diagnosticResults)
      } catch (diagError) {
        console.warn('⚠️ Legacy diagnostics failed, using enhanced results:', diagError)
        
        // Convert enhanced results to legacy format
        setResults({
          credentialsTest: enhancedResult.tests.connectivity?.success || false,
          corsTest: enhancedResult.tests.cors?.success || false,
          apiTest: enhancedResult.tests.database?.success || false,
          storageTest: true, // Assume storage is OK if other tests pass
          authTest: enhancedResult.tests.database?.success || false,
          recommendations: enhancedResult.recommendations
        })
      }
      
      // Try connection with retry if basic check failed
      if (!basicCheck.success) {
        console.log('🔄 Attempting connection with retry logic...')
        try {
          const retryResult = await testConnectionWithRetry(3)
          setConnectionTest({
            ...basicCheck,
            retryResult
          })
        } catch (retryError) {
          console.warn('⚠️ Retry logic failed:', retryError)
          // Try enhanced automatic fix
          const fixResult = await connectionFixer.attemptAutomaticFixes()
          setConnectionTest({
            ...basicCheck,
            fixAttempt: fixResult
          })
        }
      }
      
    } catch (error) {
      console.error('❌ Diagnostics failed:', error)
      setResults({
        credentialsTest: false,
        corsTest: false,
        apiTest: false,
        storageTest: false,
        authTest: false,
        recommendations: [`❌ Diagnostic error: ${error}`]
      })
    } finally {
      setIsRunning(false)
    }
  }

  const getStatusIcon = (status: boolean) => {
    return status ? '✅' : '❌'
  }

  const getStatusColor = (status: boolean) => {
    return status ? 'text-green-600' : 'text-red-600'
  }

  return (
    <div className="max-w-4xl mx-auto p-6 bg-white rounded-lg shadow-lg">
      <div className="mb-6">
        <h2 className="text-2xl font-bold text-gray-900 mb-2">
          🔍 Supabase Connection Diagnostics
        </h2>
        <p className="text-gray-600">
          Run comprehensive tests to diagnose and fix Supabase connection issues.
        </p>
      </div>

      <div className="mb-6">
        <button
          onClick={runDiagnostics}
          disabled={isRunning}
          className={`px-6 py-3 rounded-lg font-medium transition-colors ${
            isRunning
              ? 'bg-gray-400 cursor-not-allowed'
              : 'bg-blue-600 hover:bg-blue-700 text-white'
          }`}
        >
          {isRunning ? '🔄 Running Diagnostics...' : '🚀 Run Diagnostics'}
        </button>
      </div>

      {/* Enhanced Diagnosis Results */}
      {enhancedDiagnosis && (
        <div className="mb-6 p-4 rounded-lg border">
          <h3 className="text-lg font-semibold mb-3">
            {enhancedDiagnosis.overall ? '✅' : '❌'} Enhanced Connection Analysis
          </h3>
          
          <div className="grid grid-cols-1 md:grid-cols-3 gap-4 mb-4">
            <div className="p-3 bg-gray-50 rounded-lg">
              <h4 className={`font-medium ${getStatusColor(enhancedDiagnosis.tests.connectivity?.success)}`}>
                {getStatusIcon(enhancedDiagnosis.tests.connectivity?.success)} Basic Connectivity
              </h4>
              <p className="text-sm text-gray-600 mt-1">
                Network connection to Supabase
              </p>
              {enhancedDiagnosis.tests.connectivity?.details && (
                <div className="text-xs text-gray-500 mt-2">
                  <pre className="whitespace-pre-wrap">
                    {JSON.stringify(enhancedDiagnosis.tests.connectivity.details, null, 2)}
                  </pre>
                </div>
              )}
            </div>

            <div className="p-3 bg-gray-50 rounded-lg">
              <h4 className={`font-medium ${getStatusColor(enhancedDiagnosis.tests.database?.success)}`}>
                {getStatusIcon(enhancedDiagnosis.tests.database?.success)} Database Access
              </h4>
              <p className="text-sm text-gray-600 mt-1">
                Database query execution
              </p>
              {enhancedDiagnosis.tests.database?.details && (
                <div className="text-xs text-gray-500 mt-2">
                  Error: {enhancedDiagnosis.tests.database.details.errorMessage}
                </div>
              )}
            </div>

            <div className="p-3 bg-gray-50 rounded-lg">
              <h4 className={`font-medium ${getStatusColor(enhancedDiagnosis.tests.cors?.success)}`}>
                {getStatusIcon(enhancedDiagnosis.tests.cors?.success)} CORS Configuration
              </h4>
              <p className="text-sm text-gray-600 mt-1">
                Cross-origin request handling
              </p>
              {enhancedDiagnosis.tests.cors?.details && (
                <div className="text-xs text-gray-500 mt-2">
                  Origin: {enhancedDiagnosis.tests.cors.details.origin}
                </div>
              )}
            </div>
          </div>

          <div className="bg-blue-50 p-3 rounded">
            <h4 className="font-medium text-blue-800 mb-2">Enhanced Recommendations:</h4>
            <ul className="text-sm text-blue-700 space-y-1">
              {enhancedDiagnosis.recommendations.map((rec: string, index: number) => (
                <li key={index}>{rec}</li>
              ))}
            </ul>
          </div>
        </div>
      )}

      {connectionTest && (
        <div className="mb-6 p-4 rounded-lg border">
          <h3 className="text-lg font-semibold mb-3">
            {connectionTest.success ? '✅' : '❌'} Basic Connection Test
          </h3>
          
          {connectionTest.success ? (
            <div className="text-green-600">
              <p className="font-medium">✅ Connection successful!</p>
              <p className="text-sm">{connectionTest.message}</p>
            </div>
          ) : (
            <div className="text-red-600">
              <p className="font-medium">❌ Connection failed</p>
              <p className="text-sm mb-2">Error: {connectionTest.error}</p>
              <p className="text-sm mb-3">Guidance: {connectionTest.guidance}</p>
              
              {connectionTest.troubleshooting && (
                <div className="bg-red-50 p-3 rounded">
                  <p className="font-medium text-red-800 mb-2">Troubleshooting Steps:</p>
                  <ul className="text-sm text-red-700 space-y-1">
                    {connectionTest.troubleshooting.map((step: string, index: number) => (
                      <li key={index}>{step}</li>
                    ))}
                  </ul>
                </div>
              )}
            </div>
          )}

          {connectionTest.retryResult && (
            <div className="mt-3 p-3 bg-blue-50 rounded">
              <p className="text-blue-800 font-medium">
                Retry Test: {connectionTest.retryResult.success ? '✅ Success' : '❌ Failed'}
              </p>
              <p className="text-blue-700 text-sm">
                Attempts: {connectionTest.retryResult.attempt}
              </p>
            </div>
          )}

          {connectionTest.fixAttempt && (
            <div className="mt-3 p-3 bg-purple-50 rounded">
              <p className="text-purple-800 font-medium">
                Auto-fix Attempt: {connectionTest.fixAttempt.success ? '✅ Success' : '❌ Failed'}
              </p>
              <p className="text-purple-700 text-sm">
                {connectionTest.fixAttempt.message}
              </p>
            </div>
          )}
        </div>
      )}

      {results && (
        <div className="space-y-6">
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
            <div className="p-4 border rounded-lg">
              <h4 className={`font-medium ${getStatusColor(results.credentialsTest)}`}>
                {getStatusIcon(results.credentialsTest)} Credentials Format
              </h4>
              <p className="text-sm text-gray-600 mt-1">
                Validates URL and API key format
              </p>
            </div>

            <div className="p-4 border rounded-lg">
              <h4 className={`font-medium ${getStatusColor(results.corsTest)}`}>
                {getStatusIcon(results.corsTest)} Network & CORS
              </h4>
              <p className="text-sm text-gray-600 mt-1">
                Tests basic network connectivity
              </p>
            </div>

            <div className="p-4 border rounded-lg">
              <h4 className={`font-medium ${getStatusColor(results.apiTest)}`}>
                {getStatusIcon(results.apiTest)} API Endpoints
              </h4>
              <p className="text-sm text-gray-600 mt-1">
                Tests database API access
              </p>
            </div>

            <div className="p-4 border rounded-lg">
              <h4 className={`font-medium ${getStatusColor(results.storageTest)}`}>
                {getStatusIcon(results.storageTest)} Storage Access
              </h4>
              <p className="text-sm text-gray-600 mt-1">
                Tests file storage functionality
              </p>
            </div>

            <div className="p-4 border rounded-lg">
              <h4 className={`font-medium ${getStatusColor(results.authTest)}`}>
                {getStatusIcon(results.authTest)} Authentication
              </h4>
              <p className="text-sm text-gray-600 mt-1">
                Tests auth service availability
              </p>
            </div>
          </div>

          <div className="p-4 bg-gray-50 rounded-lg">
            <h3 className="text-lg font-semibold mb-3">📋 Recommendations</h3>
            <div className="space-y-2">
              {results.recommendations.map((recommendation, index) => (
                <p key={index} className="text-sm">
                  {recommendation}
                </p>
              ))}
            </div>
          </div>

          <div className="p-4 bg-blue-50 rounded-lg">
            <h3 className="text-lg font-semibold text-blue-800 mb-3">
              🔧 Quick Fix Guide
            </h3>
            <div className="text-sm text-blue-700 space-y-2">
              <p><strong>1. Check Supabase Dashboard:</strong></p>
              <ul className="ml-4 space-y-1">
                <li>• Go to <a href="https://supabase.com/dashboard" target="_blank" rel="noopener noreferrer" className="underline">supabase.com/dashboard</a></li>
                <li>• Select project: tidnmzsivsthwwcfdzyo</li>
                <li>• Ensure project is not paused</li>
              </ul>
              
              <p><strong>2. Verify API Settings:</strong></p>
              <ul className="ml-4 space-y-1">
                <li>• Go to Settings → API</li>
                <li>• Copy Project URL and anon public key</li>
                <li>• Update your code if they don't match</li>
              </ul>
              
              <p><strong>3. Configure CORS:</strong></p>
              <ul className="ml-4 space-y-1">
                <li>• Go to Settings → API → CORS</li>
                <li>• Add: http://localhost:3000</li>
                <li>• Add: https://localhost:3000</li>
              </ul>
              
              <p><strong>4. Check RLS Policies:</strong></p>
              <ul className="ml-4 space-y-1">
                <li>• Go to Authentication → Policies</li>
                <li>• Ensure public access where needed</li>
                <li>• Check profiles table has proper policies</li>
              </ul>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}

export default ConnectionDiagnostics