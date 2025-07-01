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
      
      console.log("Începerea procesului de confirmare email");
      console.log("URL:", window.location.href);
      console.log("Hash:", location.hash);
      console.log("Search params:", location.search);
      
      // Verificăm dacă avem un token de eroare în URL (pentru a afișa un mesaj mai prietenos)
      const urlParams = new URLSearchParams(window.location.search);
      const errorCode = urlParams.get('error_code');
      const errorDescription = urlParams.get('error_description');
      
      if (errorCode === 'otp_expired' || (errorDescription && errorDescription.includes('expired'))) {
        console.error('Token-ul de confirmare a expirat');
        setError('Link-ul de confirmare a expirat. Te rugăm să soliciți un nou link de confirmare din pagina de autentificare.');
        setIsConfirming(false);
        return;
      }
      
      // Verificăm mai întâi parametrii din hash (autentificare modernă Supabase)
      const hashParams = new URLSearchParams(location.hash.substring(1));
      const accessToken = hashParams.get('access_token');
      const refreshToken = hashParams.get('refresh_token');
      const type = hashParams.get('type');
      
      console.log("Parametri hash:", { 
        accessToken: accessToken ? "prezent" : "lipsă", 
        refreshToken: refreshToken ? "prezent" : "lipsă", 
        type 
      });
      
      // Dacă avem token-uri în hash-ul URL-ului
      if (accessToken && refreshToken) {
        console.log("Token-uri găsite în hash-ul URL-ului, setăm sesiunea...");
        
        // Setăm sesiunea cu token-urile
        const { data, error } = await supabase.auth.setSession({
          access_token: accessToken,
          refresh_token: refreshToken
        });
        
        if (error) {
          console.error('Eroare la setarea sesiunii:', error);
          setError('A apărut o eroare la confirmarea email-ului. Te rugăm să încerci din nou sau să contactezi suportul.');
          setIsConfirming(false);
          return;
        }
        
        console.log("Sesiune setată cu succes:", data.session ? "Sesiune prezentă" : "Fără sesiune");
        
        // Dacă tipul este signup_email_confirmation sau recovery, este o confirmare
        if (type === 'signup' || type === 'signup_email_confirmation' || type === 'recovery') {
          console.log("Email confirmat cu succes prin parametrii hash");
          setIsSuccess(true);
          setIsConfirming(false);
          return;
        }
      }
      
      // Dacă nu avem parametri hash, verificăm parametrii din query (stil vechi sau link-uri email)
      const queryParams = new URLSearchParams(location.search);
      const token = queryParams.get('token');
      const queryType = queryParams.get('type');
      
      console.log("Parametri query:", { 
        token: token ? "prezent" : "lipsă", 
        type: queryType 
      });
      
      if (token) {
        console.log("Token găsit în parametrii query, verificăm...");
        
        // Încercăm să verificăm cu token-ul
        if (queryType === 'email_confirm' || queryType === 'signup' || !queryType) {
          try {
            // Încercăm confirmarea email-ului
            const { error } = await supabase.auth.verifyOtp({
              token_hash: token,
              type: 'email_change'
            });
            
            if (error) {
              console.error('Eroare la confirmarea email-ului cu token_hash:', error);
              
              // Încercăm o metodă alternativă de verificare
              const { error: signupError } = await supabase.auth.verifyOtp({
                token_hash: token,
                type: 'signup'
              });
              
              if (signupError) {
                console.error('Eroare la confirmarea înregistrării cu token_hash:', signupError);
                setError('A apărut o eroare la confirmarea email-ului. Te rugăm să încerci din nou sau să contactezi suportul.');
                setIsConfirming(false);
                return;
              }
            }
            
            console.log("Email confirmat cu succes prin token");
            setIsSuccess(true);
            setIsConfirming(false);
          } catch (verifyError) {
            console.error('Eroare în procesul de verificare:', verifyError);
            setError('A apărut o eroare la procesarea token-ului de confirmare.');
            setIsConfirming(false);
          }
        } else {
          setError('Tip de confirmare necunoscut. Te rugăm să contactezi suportul.');
          setIsConfirming(false);
        }
      } else if (!accessToken && !refreshToken && !token) {
        // Verificăm dacă suntem pe pagina de confirmare fără parametri (poate utilizatorul a accesat direct URL-ul)
        if (location.pathname === '/auth/confirm') {
          // Verificăm dacă utilizatorul este deja autentificat
          const { data: { session } } = await supabase.auth.getSession();
          if (session) {
            console.log("Utilizatorul este deja autentificat, considerăm confirmarea reușită");
            setIsSuccess(true);
            setIsConfirming(false);
            return;
          }
        }
        
        // Nu s-au găsit token-uri în URL
        console.error('Nu s-au găsit token-uri în URL');
        setError('Link invalid sau expirat. Te rugăm să soliciți un nou link de confirmare.');
        setIsConfirming(false);
      }
      
    } catch (err) {
      console.error('Eroare în confirmEmail:', err);
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
                Felicitări! Cont confirmat cu succes!
              </h2>
              <p className="text-gray-600 mb-6">
                Bine ai venit în comunitatea Nexar! Contul tău a fost confirmat cu succes. Te poți bucura acum de toate funcționalitățile platformei. Dacă ai nevoie de asistență sau ai întrebări, echipa noastră de suport îți stă la dispoziție.
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