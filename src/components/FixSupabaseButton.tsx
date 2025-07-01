import React, { useState } from 'react';
import { RefreshCw, CheckCircle, XCircle } from 'lucide-react';
import { fixAllSupabaseIssues, clearBrowserCache, fixCookieIssues } from '../lib/fixSupabase';
import { supabase, auth } from '../lib/supabase';

interface FixSupabaseButtonProps {
  onSuccess?: () => void;
  onError?: () => void;
  buttonText?: string;
  className?: string;
}

const FixSupabaseButton: React.FC<FixSupabaseButtonProps> = ({ 
  onSuccess, 
  onError, 
  buttonText = "Repară Conexiunea",
  className = "bg-nexar-accent text-white"
}) => {
  const [isFixing, setIsFixing] = useState(false);
  const [result, setResult] = useState<{
    success?: boolean;
    message?: string;
  }>({});

  const handleFix = async () => {
    setIsFixing(true);
    setResult({});
    
    try {
      // Verificăm dacă există o sesiune invalidă
      try {
        const { data, error } = await supabase.auth.getSession();
        
        if (error && (error.message?.includes('User from sub claim in JWT does not exist') || 
                      error.code === 'user_not_found')) {
          console.log('🔄 Detected invalid JWT session, clearing...');
          await auth.signOut();
        }
      } catch (sessionError) {
        console.error('Error checking session:', sessionError);
      }
      
      // Curățăm cache-ul și cookie-urile mai întâi
      clearBrowserCache();
      fixCookieIssues();
      
      // Apoi reparăm conexiunea Supabase
      const fixResult = await fixAllSupabaseIssues();
      
      setResult({
        success: fixResult.success,
        message: fixResult.message
      });
      
      if (fixResult.success) {
        if (onSuccess) {
          setTimeout(onSuccess, 1500);
        } else {
          // Reîncărcăm pagina după 2 secunde
          setTimeout(() => {
            window.location.reload();
          }, 2000);
        }
      } else if (onError) {
        onError();
      }
      
    } catch (error) {
      console.error('Eroare la repararea conexiunii:', error);
      setResult({
        success: false,
        message: 'A apărut o eroare neașteptată'
      });
      
      if (onError) onError();
    } finally {
      setIsFixing(false);
    }
  };

  return (
    <div className="flex flex-col items-center">
      <button
        onClick={handleFix}
        disabled={isFixing}
        className={`flex items-center space-x-2 ${className} px-4 py-2 rounded-lg font-semibold hover:bg-nexar-gold transition-colors disabled:opacity-50 disabled:cursor-not-allowed`}
      >
        {isFixing ? (
          <>
            <div className="w-5 h-5 border-2 border-white border-t-transparent rounded-full animate-spin"></div>
            <span>Se repară...</span>
          </>
        ) : (
          <>
            <RefreshCw className="h-5 w-5" />
            <span>{buttonText}</span>
          </>
        )}
      </button>
      
      {result.message && (
        <div className={`mt-3 p-3 rounded-lg ${
          result.success ? 'bg-green-100 text-green-800' : 'bg-red-100 text-red-800'
        }`}>
          <div className="flex items-center space-x-2">
            {result.success ? (
              <CheckCircle className="h-5 w-5" />
            ) : (
              <XCircle className="h-5 w-5" />
            )}
            <span>{result.message}</span>
          </div>
        </div>
      )}
    </div>
  );
};

export default FixSupabaseButton;