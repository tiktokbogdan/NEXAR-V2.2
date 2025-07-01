import React, { useState, useMemo, useEffect } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { Search, Filter, MapPin, Calendar, Gauge, ChevronLeft, ChevronRight, Settings, Fuel, User, X, SlidersHorizontal, Building, RefreshCw } from 'lucide-react';
import { listings, supabase, romanianCities } from '../lib/supabase';

const ListingsPage = () => {
  // On desktop, show filters by default. On mobile, hide them by default
  const [showFilters, setShowFilters] = useState(window.innerWidth >= 1024);
  const [currentPage, setCurrentPage] = useState(1);
  const [searchQuery, setSearchQuery] = useState('');
  const [filters, setFilters] = useState({
    priceMin: '',
    priceMax: '',
    category: '',
    brand: '',
    yearMin: '',
    yearMax: '',
    mileageMax: '',
    location: '',
    fuel: '',
    transmission: '',
    engineMin: '',
    engineMax: '',
    condition: '',
    sellerType: ''
  });
  const [allListings, setAllListings] = useState<any[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const itemsPerPage = 10;
  const navigate = useNavigate();

  // Update showFilters state when window is resized
  useEffect(() => {
    const handleResize = () => {
      setShowFilters(window.innerWidth >= 1024);
    };

    window.addEventListener('resize', handleResize);
    return () => window.removeEventListener('resize', handleResize);
  }, []);

  // Scroll to top when component mounts
  useEffect(() => {
    window.scrollTo(0, 0);
    loadListings();
  }, []);

  // Load real listings from Supabase
  const loadListings = async () => {
    try {
      setIsLoading(true);
      setError(null);
      
      console.log('🔄 Loading listings from Supabase...');
      
      const { data, error } = await listings.getAll();
      
      if (error) {
        console.error('❌ Error loading listings:', error);
        setError('Nu s-au putut încărca anunțurile');
        return;
      }
      
      console.log('✅ Loaded listings:', data?.length || 0);
      
      // Formatăm datele pentru afișare
      const formattedListings = (data || []).map((listing: any) => ({
        id: listing.id,
        title: listing.title,
        price: listing.price,
        year: listing.year,
        mileage: listing.mileage,
        location: listing.location,
        image: listing.images && listing.images.length > 0 ? listing.images[0] : "https://images.pexels.com/photos/2116475/pexels-photo-2116475.jpeg",
        seller: listing.seller_name,
        sellerId: listing.seller_id,
        sellerType: listing.seller_type,
        category: listing.category,
        brand: listing.brand,
        model: listing.model,
        engine: listing.engine_capacity,
        fuel: listing.fuel_type,
        transmission: listing.transmission,
        condition: listing.condition,
        featured: listing.featured || false,
        views_count: listing.views_count || 0,
        favorites_count: listing.favorites_count || 0,
        created_at: listing.created_at,
        status: listing.status
      }));
      
      setAllListings(formattedListings);
      
    } catch (err) {
      console.error('💥 Error in loadListings:', err);
      setError('A apărut o eroare la încărcarea anunțurilor');
    } finally {
      setIsLoading(false);
    }
  };

  // Filtrare și căutare avansată
  const filteredListings = useMemo(() => {
    return allListings.filter(listing => {
      // Căutare în text
      const searchLower = searchQuery.toLowerCase();
      const matchesSearch = !searchQuery || 
        listing.title.toLowerCase().includes(searchLower) ||
        listing.brand.toLowerCase().includes(searchLower) ||
        listing.model.toLowerCase().includes(searchLower) ||
        listing.category.toLowerCase().includes(searchLower) ||
        listing.location.toLowerCase().includes(searchLower) ||
        listing.seller.toLowerCase().includes(searchLower);

      // Filtre
      const matchesPrice = (!filters.priceMin || listing.price >= parseInt(filters.priceMin)) &&
                          (!filters.priceMax || listing.price <= parseInt(filters.priceMax));
      
      const matchesCategory = !filters.category || listing.category.toLowerCase() === filters.category.toLowerCase();
      
      const matchesBrand = !filters.brand || listing.brand.toLowerCase() === filters.brand.toLowerCase();
      
      const matchesYear = (!filters.yearMin || listing.year >= parseInt(filters.yearMin)) &&
                         (!filters.yearMax || listing.year <= parseInt(filters.yearMax));
      
      const matchesMileage = !filters.mileageMax || listing.mileage <= parseInt(filters.mileageMax);
      
      const matchesLocation = !filters.location || listing.location.toLowerCase().includes(filters.location.toLowerCase());
      
      const matchesFuel = !filters.fuel || listing.fuel.toLowerCase() === filters.fuel.toLowerCase();
      
      const matchesTransmission = !filters.transmission || listing.transmission.toLowerCase() === filters.transmission.toLowerCase();
      
      const matchesEngine = (!filters.engineMin || listing.engine >= parseInt(filters.engineMin)) &&
                           (!filters.engineMax || listing.engine <= parseInt(filters.engineMax));
      
      const matchesCondition = !filters.condition || listing.condition.toLowerCase() === filters.condition.toLowerCase();
      
      const matchesSellerType = !filters.sellerType || 
                               (filters.sellerType === 'individual' && listing.sellerType === 'individual') ||
                               (filters.sellerType === 'dealer' && listing.sellerType === 'dealer');

      return matchesSearch && matchesPrice && matchesCategory && matchesBrand && 
             matchesYear && matchesMileage && matchesLocation && matchesFuel && 
             matchesTransmission && matchesEngine && matchesCondition && matchesSellerType;
    });
  }, [searchQuery, filters, allListings]);

  // Calculate pagination
  const totalPages = Math.ceil(filteredListings.length / itemsPerPage);
  const startIndex = (currentPage - 1) * itemsPerPage;
  const endIndex = startIndex + itemsPerPage;
  const currentListings = filteredListings.slice(startIndex, endIndex);

  const handleFilterChange = (key: string, value: string) => {
    setFilters(prev => ({ ...prev, [key]: value }));
    setCurrentPage(1); // Reset to first page when filtering
  };

  const clearFilters = () => {
    setFilters({
      priceMin: '',
      priceMax: '',
      category: '',
      brand: '',
      yearMin: '',
      yearMax: '',
      mileageMax: '',
      location: '',
      fuel: '',
      transmission: '',
      engineMin: '',
      engineMax: '',
      condition: '',
      sellerType: ''
    });
    setSearchQuery('');
    setCurrentPage(1);
  };

  const handleSearch = (e: React.FormEvent) => {
    e.preventDefault();
    setCurrentPage(1);
  };

  const handleSellerClick = (e: React.MouseEvent, sellerId: string) => {
    e.preventDefault();
    e.stopPropagation();
    navigate(`/profil/${sellerId}`);
    window.scrollTo(0, 0);
  };

  const ListingRow = ({ listing }: { listing: any }) => (
    <Link
      to={`/anunt/${listing.id}`}
      className="bg-white rounded-xl shadow-sm overflow-hidden hover:shadow-lg transition-all duration-300 group border border-gray-100 block"
    >
      <div className="flex flex-col sm:flex-row">
        <div className="relative w-full sm:w-64 flex-shrink-0">
          <img
          loading="lazy"
            src={listing.image}
            alt={listing.title}
            className="w-full h-48 sm:h-48 object-cover group-hover:scale-105 transition-transform duration-300"
            onError={(e) => {
              // Fallback la imagine placeholder dacă imaginea nu se încarcă
              const target = e.currentTarget as HTMLImageElement;
              target.src = "https://images.pexels.com/photos/2116475/pexels-photo-2116475.jpeg";
            }}
          />
          <div className="absolute top-3 left-3">
            <span className="bg-nexar-accent text-white px-3 py-1 rounded-full text-xs font-semibold">
              {listing.category}
            </span>
          </div>
        </div>
        
        <div className="flex-1 p-4 sm:p-6">
          <div className="flex flex-col sm:flex-row sm:justify-between sm:items-start mb-3">
            <div>
              <h3 className="text-lg sm:text-xl font-bold text-gray-900 group-hover:text-nexar-accent transition-colors mb-2">
                {listing.brand} {listing.model}
              </h3>
              <div className="text-xl sm:text-2xl font-bold text-gray-900 mb-2">€{listing.price.toLocaleString()}</div>
              
              {/* EVIDENȚIERE DEALER MULT MAI PRONUNȚATĂ */}
              <div className="flex flex-col sm:flex-row sm:items-center gap-2 mb-2">
                <div className="text-sm text-gray-600">
                  Vândut de: 
                  <button 
                    onClick={(e) => handleSellerClick(e, listing.sellerId)}
                    className="font-semibold text-nexar-accent hover:text-nexar-gold transition-colors ml-1 underline"
                  >
                    {listing.seller}
                  </button>
                </div>
                
                {/* BADGE DEALER MULT MAI VIZIBIL */}
                {listing.sellerType === 'dealer' ? (
                  <div className="inline-flex items-center space-x-2 bg-gradient-to-r from-emerald-500 to-emerald-600 text-white px-3 py-1.5 rounded-full shadow-md border border-emerald-400">
                    <Building className="h-3 w-3" />
                    <span className="font-bold text-xs tracking-wide">DEALER PREMIUM</span>
                    <div className="w-1.5 h-1.5 bg-white rounded-full animate-pulse"></div>
                  </div>
                ) : (
                  <div className="inline-flex items-center space-x-2 bg-gradient-to-r from-slate-500 to-slate-600 text-white px-3 py-1.5 rounded-full shadow-md">
                    <User className="h-3 w-3" />
                    <span className="font-semibold text-xs">PRIVAT</span>
                  </div>
                )}
              </div>
            </div>
          </div>
          
          {/* Detailed Information Grid */}
          <div className="grid grid-cols-2 lg:grid-cols-4 gap-4 mb-4 text-sm">
            <div className="flex items-center justify-between">
              <span className="text-gray-600">Locație:</span>
              <span className="font-semibold text-gray-900">{listing.location}</span>
            </div>
            <div className="flex items-center justify-between">
              <span className="text-gray-600">Stare:</span>
              <span className="font-semibold text-gray-900">{listing.condition}</span>
            </div>
            <div className="flex items-center justify-between">
              <span className="text-gray-600">Vânzător:</span>
              <span className="font-semibold text-gray-900">{listing.sellerType === 'individual' ? 'Individual' : 'Dealer'}</span>
            </div>
            <div className="flex items-center justify-between">
              <span className="text-gray-600">Kilometraj:</span>
              <span className="font-semibold text-gray-900">{listing.mileage.toLocaleString()} km</span>
            </div>
            <div className="flex items-center justify-between">
              <span className="text-gray-600">Transmisie:</span>
              <span className="font-semibold text-gray-900">{listing.transmission}</span>
            </div>
            <div className="flex items-center justify-between">
              <span className="text-gray-600">Combustibil:</span>
              <span className="font-semibold text-gray-900">{listing.fuel}</span>
            </div>
            <div className="flex items-center justify-between">
              <span className="text-gray-600">Motor:</span>
              <span className="font-semibold text-gray-900">{listing.engine} cc</span>
            </div>
            <div className="flex items-center justify-between">
              <span className="text-gray-600">An:</span>
              <span className="font-semibold text-gray-900">{listing.year}</span>
            </div>
          </div>
          
          <div className="flex items-center justify-between">
            <div className="text-sm text-gray-600">
              Vândut de: <span className="font-semibold text-gray-700">{listing.seller}</span>
            </div>
            
            <div className="bg-nexar-accent text-white px-6 py-2.5 rounded-lg font-semibold hover:bg-nexar-gold transition-colors inline-flex items-center space-x-2">
              <span>Vezi Detalii</span>
            </div>
          </div>
        </div>
      </div>
    </Link>
  );

  return (
    <div className="min-h-screen bg-gray-50 py-6">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        {/* Header */}
        <div className="mb-6">
          <h1 className="text-2xl md:text-3xl font-bold text-gray-900 mb-3">
            Toate Anunțurile
          </h1>
          <p className="text-gray-600">
            Descoperă {filteredListings.length} motociclete disponibile pentru vânzare
          </p>
        </div>

        {/* Search Bar - Single, prominent */}
        <div className="bg-white rounded-xl shadow-sm p-6 mb-6 border border-gray-100">
          <form onSubmit={handleSearch} className="flex flex-col lg:flex-row gap-4">
            <div className="flex-1">
              <div className="relative">
                <input
                  type="text"
                  value={searchQuery}
                  onChange={(e) => setSearchQuery(e.target.value)}
                  placeholder="Caută după marcă, model, categorie, locație sau vânzător..."
                  className="w-full pl-12 pr-4 py-3 border border-gray-200 rounded-lg focus:ring-2 focus:ring-nexar-accent focus:border-transparent text-base"
                />
                <Search className="absolute left-4 top-1/2 transform -translate-y-1/2 text-gray-400 h-5 w-5" />
              </div>
            </div>
            
            <div className="flex gap-3">
              <button
                type="submit"
                className="bg-nexar-accent text-white px-6 py-3 rounded-lg font-semibold hover:bg-nexar-gold transition-colors flex items-center space-x-2"
              >
                <Search className="h-4 w-4" />
                <span>Caută</span>
              </button>
              
              <button
                type="button"
                onClick={() => setShowFilters(!showFilters)}
                className="flex items-center space-x-2 bg-gray-100 text-gray-700 px-6 py-3 rounded-lg font-semibold hover:bg-gray-200 transition-colors"
              >
                <SlidersHorizontal className="h-4 w-4" />
                <span>{showFilters ? 'Ascunde' : 'Arată'} Filtrele</span>
              </button>
            </div>
          </form>
        </div>

        <div className="flex flex-col lg:flex-row gap-6">
          {/* Filters Sidebar */}
          {showFilters && (
            <div className="w-full lg:w-80 transition-all duration-300">
              <div className="bg-white rounded-xl shadow-sm p-6 lg:sticky lg:top-24 border border-gray-100">
                <div className="flex items-center justify-between mb-6">
                  <h3 className="text-lg font-semibold text-gray-900 flex items-center space-x-2">
                    <Filter className="h-5 w-5" />
                    <span>Filtrează Rezultatele</span>
                  </h3>
                  <button
                    onClick={() => setShowFilters(false)}
                    className="p-1 hover:bg-gray-100 rounded-lg transition-colors"
                  >
                    <X className="h-4 w-4" />
                  </button>
                </div>

                <div className="space-y-6 max-h-[calc(100vh-200px)] overflow-y-auto">
                  {/* Price Range */}
                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-3">💰 Preț (EUR)</label>
                    <div className="grid grid-cols-2 gap-2">
                      <input
                        type="number"
                        placeholder="Min"
                        value={filters.priceMin}
                        onChange={(e) => handleFilterChange('priceMin', e.target.value)}
                        className="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-nexar-accent focus:border-transparent"
                      />
                      <input
                        type="number"
                        placeholder="Max"
                        value={filters.priceMax}
                        onChange={(e) => handleFilterChange('priceMax', e.target.value)}
                        className="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-nexar-accent focus:border-transparent"
                      />
                    </div>
                  </div>

                  {/* Category */}
                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-3">🏍️ Categorie</label>
                    <select
                      value={filters.category}
                      onChange={(e) => handleFilterChange('category', e.target.value)}
                      className="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-nexar-accent focus:border-transparent"
                    >
                      <option value="">Toate categoriile</option>
                      <option value="sport">Sport</option>
                      <option value="touring">Touring</option>
                      <option value="cruiser">Cruiser</option>
                      <option value="adventure">Adventure</option>
                      <option value="naked">Naked</option>
                      <option value="enduro">Enduro</option>
                      <option value="scooter">Scooter</option>
                      <option value="chopper">Chopper</option>
                      <option value="cafe Racer">Cafe Racer</option>
                      <option value="supermoto">Supermoto</option>
                      <option value="motocross">Motocross</option>
                      <option value="trial">Trial</option>
                    </select>
                  </div>

                  {/* Brand */}
                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-3">🏭 Marcă</label>
                    <select
                      value={filters.brand}
                      onChange={(e) => handleFilterChange('brand', e.target.value)}
                      className="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-nexar-accent focus:border-transparent"
                    >
                      <option value="">Toate mărcile</option>
                      <option value="Yamaha">Yamaha</option>
                      <option value="Honda">Honda</option>
                      <option value="BMW">BMW</option>
                      <option value="Ducati">Ducati</option>
                      <option value="KTM">KTM</option>
                      <option value="Suzuki">Suzuki</option>
                      <option value="Harley-Davidson">Harley-Davidson</option>
                      <option value="Kawasaki">Kawasaki</option>
                      <option value="Triumph">Triumph</option>
                      <option value="Aprilia">Aprilia</option>
                    </select>
                  </div>

                  {/* Year Range */}
                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-3">📅 An fabricație</label>
                    <div className="grid grid-cols-2 gap-2">
                      <input
                        type="number"
                        placeholder="De la"
                        value={filters.yearMin}
                        onChange={(e) => handleFilterChange('yearMin', e.target.value)}
                        className="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-nexar-accent focus:border-transparent"
                      />
                      <input
                        type="number"
                        placeholder="Până la"
                        value={filters.yearMax}
                        onChange={(e) => handleFilterChange('yearMax', e.target.value)}
                        className="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-nexar-accent focus:border-transparent"
                      />
                    </div>
                  </div>

                  {/* Engine Capacity */}
                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-3">⚙️ Capacitate motor (cc)</label>
                    <div className="grid grid-cols-2 gap-2">
                      <input
                        type="number"
                        placeholder="Min"
                        value={filters.engineMin}
                        onChange={(e) => handleFilterChange('engineMin', e.target.value)}
                        className="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-nexar-accent focus:border-transparent"
                      />
                      <input
                        type="number"
                        placeholder="Max"
                        value={filters.engineMax}
                        onChange={(e) => handleFilterChange('engineMax', e.target.value)}
                        className="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-nexar-accent focus:border-transparent"
                      />
                    </div>
                  </div>

                  {/* Mileage */}
                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-3">🛣️ Kilometraj maxim</label>
                    <input
                      type="number"
                      placeholder="ex: 50000"
                      value={filters.mileageMax}
                      onChange={(e) => handleFilterChange('mileageMax', e.target.value)}
                      className="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-nexar-accent focus:border-transparent"
                    />
                  </div>

                  {/* Fuel Type */}
                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-3">⛽ Combustibil</label>
                    <select
                      value={filters.fuel}
                      onChange={(e) => handleFilterChange('fuel', e.target.value)}
                      className="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-nexar-accent focus:border-transparent"
                    >
                      <option value="">Toate tipurile</option>
                      <option value="Benzină">Benzină</option>
                      <option value="Electric">Electric</option>
                      <option value="Hibrid">Hibrid</option>
                    </select>
                  </div>

                  {/* Transmission */}
                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-3">🔧 Transmisie</label>
                    <select
                      value={filters.transmission}
                      onChange={(e) => handleFilterChange('transmission', e.target.value)}
                      className="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-nexar-accent focus:border-transparent"
                    >
                      <option value="">Toate tipurile</option>
                      <option value="Manuală">Manuală</option>
                      <option value="Automată">Automată</option>
                      <option value="Semi-automată">Semi-automată</option>
                    </select>
                  </div>

                  {/* Condition */}
                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-3">✨ Starea</label>
                    <select
                      value={filters.condition}
                      onChange={(e) => handleFilterChange('condition', e.target.value)}
                      className="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-nexar-accent focus:border-transparent"
                    >
                      <option value="">Toate stările</option>
                      <option value="La comandă">La comandă</option>
                      <option value="Excelentă">Excelentă</option>
                      <option value="Foarte bună">Foarte bună</option>
                      <option value="Bună">Bună</option>
                      <option value="Satisfăcătoare">Satisfăcătoare</option>
                    </select>
                  </div>

                  {/* Seller Type */}
                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-3">👤 Tip vânzător</label>
                    <select
                      value={filters.sellerType}
                      onChange={(e) => handleFilterChange('sellerType', e.target.value)}
                      className="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-nexar-accent focus:border-transparent"
                    >
                      <option value="">Toți vânzătorii</option>
                      <option value="individual">Vânzător Individual</option>
                      <option value="dealer">Dealer Autorizat</option>
                    </select>
                  </div>

                  {/* Location */}
                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-3">📍 Locația</label>
                    <select
                      value={filters.location}
                      onChange={(e) => handleFilterChange('location', e.target.value)}
                      className="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-nexar-accent focus:border-transparent"
                    >
                      <option value="">Toate locațiile</option>
                      <option value="București S1">București S1</option>
                      <option value="București S2">București S2</option>
                      <option value="București S3">București S3</option>
                      <option value="București S4">București S4</option>
                      <option value="București S5">București S5</option>
                      <option value="București S6">București S6</option>
                      <option value="Cluj-Napoca">Cluj-Napoca</option>
                      <option value="Timișoara">Timișoara</option>
                      <option value="Iași">Iași</option>
                      <option value="Constanța">Constanța</option>
                      <option value="Brașov">Brașov</option>
                      <option value="Craiova">Craiova</option>
                      <option value="Galați">Galați</option>
                      <option value="Oradea">Oradea</option>
                      <option value="Ploiești">Ploiești</option>
                      <option value="Sibiu">Sibiu</option>
                      <option value="Bacău">Bacău</option>
                      <option value="Râmnicu Vâlcea">Râmnicu Vâlcea</option>
                      {romanianCities.map(city => (
                        !city.startsWith("București") && 
                        city !== "Râmnicu Vâlcea" && 
                        city !== "Rm. Vâlcea" && (
                          <option key={city} value={city}>{city}</option>
                        )
                      ))}
                    </select>
                  </div>

                  {/* Clear Filters */}
                  <button
                    onClick={clearFilters}
                    className="w-full bg-gray-100 text-gray-700 py-3 rounded-lg font-semibold hover:bg-gray-200 transition-colors flex items-center justify-center space-x-2"
                  >
                    <X className="h-4 w-4" />
                    <span>Șterge Toate Filtrele</span>
                  </button>
                </div>
              </div>
            </div>
          )}

          {/* Main Content */}
          <div className="flex-1">
            {/* Results */}
            <div className="mb-5">
              <div className="flex justify-between items-center">
                <p className="text-gray-600">
                  {isLoading ? (
                    <span>Se încarcă anunțurile...</span>
                  ) : (
                    <>
                      Afișez <span className="font-semibold">{filteredListings.length > 0 ? startIndex + 1 : 0}-{Math.min(endIndex, filteredListings.length)}</span> din <span className="font-semibold">{filteredListings.length}</span> rezultate
                      {searchQuery && (
                        <span className="ml-2 text-nexar-accent">
                          pentru "{searchQuery}"
                        </span>
                      )}
                    </>
                  )}
                </p>
                <select className="border border-gray-200 rounded-lg px-3 py-2 focus:ring-2 focus:ring-nexar-accent focus:border-transparent">
                  <option>Sortează după: Cel mai recent</option>
                  <option>Preț: Crescător</option>
                  <option>Preț: Descrescător</option>
                  <option>An: Cel mai nou</option>
                  <option>Kilometraj: Cel mai mic</option>
                </select>
              </div>
            </div>

            {/* Loading State */}
            {isLoading && (
              <div className="bg-white rounded-xl shadow-sm p-12 text-center border border-gray-100">
                <div className="w-16 h-16 border-4 border-nexar-accent border-t-transparent rounded-full animate-spin mx-auto mb-4"></div>
                <h3 className="text-xl font-semibold text-gray-900 mb-2">Se încarcă anunțurile...</h3>
                <p className="text-gray-600">Te rugăm să aștepți</p>
              </div>
            )}

            {/* Error State */}
            {!isLoading && error && (
              <div className="bg-white rounded-xl shadow-sm p-12 text-center border border-gray-100">
                <div className="w-16 h-16 bg-red-100 rounded-full flex items-center justify-center mx-auto mb-4">
                  <X className="h-8 w-8 text-red-500" />
                </div>
                <h3 className="text-xl font-semibold text-gray-900 mb-2">Eroare la încărcare</h3>
                <p className="text-gray-600 mb-6">{error}</p>
                <div className="flex flex-col sm:flex-row gap-4 justify-center">
                  <button
                    onClick={loadListings}
                    className="bg-nexar-accent text-white px-6 py-3 rounded-lg font-semibold hover:bg-nexar-gold transition-colors flex items-center justify-center space-x-2"
                  >
                    <RefreshCw className="h-5 w-5" />
                    <span>Încearcă din nou</span>
                  </button>
                </div>
              </div>
            )}

            {/* No Results */}
            {!isLoading && !error && filteredListings.length === 0 && (
              <div className="bg-white rounded-xl shadow-sm p-12 text-center border border-gray-100">
                <Search className="h-16 w-16 text-gray-400 mx-auto mb-4" />
                <h3 className="text-xl font-semibold text-gray-900 mb-2">Nu am găsit rezultate</h3>
                <p className="text-gray-600 mb-6">
                  {allListings.length === 0 
                    ? 'Nu există anunțuri publicate încă. Fii primul care adaugă un anunț!'
                    : 'Încearcă să modifici criteriile de căutare sau filtrele pentru a găsi mai multe rezultate.'
                  }
                </p>
                {allListings.length === 0 ? (
                  <Link
                    to="/adauga-anunt"
                    className="bg-nexar-accent text-white px-6 py-3 rounded-lg font-semibold hover:bg-nexar-gold transition-colors"
                  >
                    Adaugă primul anunț
                  </Link>
                ) : (
                  <button
                    onClick={clearFilters}
                    className="bg-nexar-accent text-white px-6 py-3 rounded-lg font-semibold hover:bg-nexar-gold transition-colors"
                  >
                    Șterge Toate Filtrele
                  </button>
                )}
              </div>
            )}

            {/* Listings List */}
            {!isLoading && !error && filteredListings.length > 0 && (
              <div className="space-y-4">
                {currentListings.map((listing) => (
                  <ListingRow key={listing.id} listing={listing} />
                ))}
              </div>
            )}

            {/* Pagination */}
            {!isLoading && !error && filteredListings.length > 0 && totalPages > 1 && (
              <div className="mt-8 flex justify-center">
                <div className="flex items-center space-x-2">
                  <button
                    onClick={() => setCurrentPage(Math.max(1, currentPage - 1))}
                    disabled={currentPage === 1}
                    className="flex items-center space-x-1 px-3 py-2 border border-gray-200 rounded-lg hover:bg-gray-50 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
                  >
                    <ChevronLeft className="h-4 w-4" />
                    <span>Anterior</span>
                  </button>
                  
                  {[...Array(totalPages)].map((_, index) => {
                    const page = index + 1;
                    return (
                      <button
                        key={page}
                        onClick={() => setCurrentPage(page)}
                        className={`px-3 py-2 rounded-lg transition-colors ${
                          currentPage === page
                            ? 'bg-nexar-accent text-white'
                            : 'border border-gray-200 hover:bg-gray-50'
                        }`}
                      >
                        {page}
                      </button>
                    );
                  })}
                  
                  <button
                    onClick={() => setCurrentPage(Math.min(totalPages, currentPage + 1))}
                    disabled={currentPage === totalPages}
                    className="flex items-center space-x-1 px-3 py-2 border border-gray-200 rounded-lg hover:bg-gray-50 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
                  >
                    <span>Următorul</span>
                    <ChevronRight className="h-4 w-4" />
                  </button>
                </div>
              </div>
            )}
          </div>
        </div>
      </div>
    </div>
  );
};

export default ListingsPage;