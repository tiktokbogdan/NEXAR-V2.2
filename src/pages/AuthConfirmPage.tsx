import React, { useEffect, useState } from 'react';
import { Link, useNavigate, useLocation } from 'react-router-dom';
import { CheckCircle, AlertTriangle, Home, LogIn } from 'lucide-react';
import { supabase } from '../lib/supabase';

const AuthConfirmPage = () => {
  const [isConfirming, setIsConfirming] = useState(true);
  const [isSuccess, setIsSuccess] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const navigate = useNavigate();
  const location = useLocation();

  useEffect(() => {
    window.scrollTo(0, 0);
    confirmEmail();
  }, []);

  const confirmEmail = async () => {
    try {
      setIsConfirming(true);
      setError(null);
      
      // Obținem token-ul din URL
      const params = new URLSearchParams(location.search);
      const token = params.get('token');
      const type = params.get('type');
      
      if (!token || type !== 'email_confirm') {
        setError('Link invalid sau expirat. Te rugăm să soliciți un nou link de confirmare.');
        setIsConfirming(false);
        return;
      }
      
      // Confirmăm email-ul
      const { error } = await supabase.auth.verifyOtp({
        token_hash: token,
        type: 'email_change'
      });
      
      if (error) {
        console.error('Error confirming email:', error);
        setError('A apărut o eroare la confirmarea email-ului. Te rugăm să încerci din nou sau să contactezi suportul.');
        setIsConfirming(false);
        return;
      }
      
      // Succes
      setIsSuccess(true);
      setIsConfirming(false);
      
    } catch (err) {
      console.error('Error in confirmEmail:', err);
      setError('A apărut o eroare neașteptată. Te rugăm să încerci din nou sau să contactezi suportul.');
      setIsConfirming(false);
    }
  };

  return (
    <div className="min-h-screen bg-gradient-to-br from-gray-900 via-gray-800 to-black flex items-center justify-center py-12 px-4 sm:px-6 lg:px-8">
      <div className="max-w-md w-full space-y-8">
        <div className="bg-white rounded-2xl shadow-2xl p-8">
          {/* Logo */}
          <div className="flex justify-center mb-6">
            <img 
              src="/Nexar - logo_black & red.png" 
              alt="Nexar Logo" 
              className="h-24 w-auto"
              onError={(e) => {
                const target = e.currentTarget as HTMLImageElement;
                if (target.src.includes('Nexar - logo_black & red.png')) {
                  target.src = '/nexar-logo.png';
                } else if (target.src.includes('nexar-logo.png')) {
                  target.src = '/image.png';
                } else {
                  target.style.display = 'none';
                }
              }}
            />
          </div>
          
          {isConfirming ? (
            <div className="text-center">
              <div className="w-16 h-16 border-4 border-nexar-accent border-t-transparent rounded-full animate-spin mx-auto mb-4"></div>
              <h2 className="text-xl font-bold text-gray-900 mb-2">
                Se confirmă email-ul...
              </h2>
              <p className="text-gray-600">
                Te rugăm să aștepți câteva momente.
              </p>
            </div>
          ) : isSuccess ? (
            <div className="text-center">
              <div className="w-16 h-16 bg-green-100 rounded-full flex items-center justify-center mx-auto mb-4">
                <CheckCircle className="h-8 w-8 text-green-500" />
              </div>
              <h2 className="text-xl font-bold text-gray-900 mb-2">
                Cont confirmat cu succes!
              </h2>
              <p className="text-gray-600 mb-6">
                Bine ai venit! Contul tău Nexar a fost confirmat cu succes. Te poți bucura acum de toate funcționalitățile platformei. Dacă ai nevoie de asistență sau ai întrebări, echipa noastră de suport îți stă la dispoziție.
              </p>
              <div className="flex flex-col sm:flex-row space-y-3 sm:space-y-0 sm:space-x-3">
                <Link
                  to="/auth"
                  className="flex-1 bg-nexar-accent text-white py-3 rounded-lg font-semibold hover:bg-nexar-gold transition-colors flex items-center justify-center space-x-2"
                >
                  <LogIn className="h-5 w-5" />
                  <span>Conectează-te</span>
                </Link>
                <Link
                  to="/"
                  className="flex-1 bg-gray-200 text-gray-800 py-3 rounded-lg font-semibold hover:bg-gray-300 transition-colors flex items-center justify-center space-x-2"
                >
                  <Home className="h-5 w-5" />
                  <span>Pagina Principală</span>
                </Link>
              </div>
            </div>
          ) : (
            <div className="text-center">
              <div className="w-16 h-16 bg-red-100 rounded-full flex items-center justify-center mx-auto mb-4">
                <AlertTriangle className="h-8 w-8 text-red-500" />
              </div>
              <h2 className="text-xl font-bold text-gray-900 mb-2">
                Eroare la confirmarea contului
              </h2>
              <p className="text-gray-600 mb-6">
                {error || 'A apărut o eroare la confirmarea contului tău. Te rugăm să încerci din nou sau să contactezi suportul.'}
              </p>
              <div className="flex flex-col sm:flex-row space-y-3 sm:space-y-0 sm:space-x-3">
                <Link
                  to="/auth"
                  className="flex-1 bg-nexar-accent text-white py-3 rounded-lg font-semibold hover:bg-nexar-gold transition-colors flex items-center justify-center space-x-2"
                >
                  <LogIn className="h-5 w-5" />
                  <span>Încearcă să te conectezi</span>
                </Link>
                <Link
                  to="/"
                  className="flex-1 bg-gray-200 text-gray-800 py-3 rounded-lg font-semibold hover:bg-gray-300 transition-colors flex items-center justify-center space-x-2"
                >
                  <Home className="h-5 w-5" />
                  <span>Pagina Principală</span>
                </Link>
              </div>
            </div>
          )}
        </div>
      </div>
    </div>
  );
};

export default AuthConfirmPage;