type Stocks: void {
    .stock[0,*]: StockSubStruct
}

type StockSubStruct: void {
    .static: StockStaticStruct
    .dynamic: StockDynamicStruct
}

// informazioni caricate dal file di configurazione xml (filename è aggiunto a runtime)
type StockStaticStruct: void {
    .filename: string
    .name: string
    .info: void {
        .availability: int
        .price: double
        .wasting: void {
            .low: int
            .high: int
            .interval: int
        }
        .production: void {
            .low: int
            .high: int
            .interval: int
        }
    }
}

// informazioni a runtime dello specifico stock
type StockDynamicStruct: void {
    .availability: int
}

type StockRegistrationStruct: void {
    .name: string
    .price: double
}

// struttura dati utilizzata dallo stock per comunicare al market la variazione di produzione / deperimento
type StockVariationStruct: void {
    .name: string
    .variation: double
}

type StocksDiscovererExceptionType: void {
    .message: string
}

type StockNameExceptionType: void {
    .stockName: string
}

// connette StocksLauncher e StocksMng
interface StocksLauncherInterface {
    RequestResponse: discover( int )( void ) throws StocksDiscovererException( StocksDiscovererExceptionType )
                                                    IOException( IOExceptionType )
                                                    FileNotFound ( FileNotFoundType )
}

// interfaccia di comunicazione con ciascuna stock instance dinamicamente allocata (ed embeddata) all'interno di StocksMng.ol
interface StockInstanceInterface {
// TODO: si vedano gli specifici todo all'interno di Stock.ol in relazione alle operazioni indicate
// (in sintesi dobbiam capire cosa / se / come struttura la response)
// messo boolean come response
    RequestResponse: start( StockSubStruct )( void ) throws StockDuplicatedException( StockNameExceptionType )
    RequestResponse: buyStock( void )( bool ) throws StockUnknownException( StockNameExceptionType )
    RequestResponse: sellStock( void )( bool ) throws StockUnknownException( StockNameExceptionType )
    RequestResponse: infoStockAvailability( void )( int ) throws StockUnknownException( StockNameExceptionType )
}

// from stocks to market
interface StockToMarketCommunicationInterface {
    RequestResponse: registerStock( StockRegistrationStruct )( string ) throws StockDuplicatedException( StockNameExceptionType )
// TODO: sicuri non sia necessaria una RequestResponse ?
    OneWay: addStock( StockVariationStruct )
    OneWay: destroyStock( StockVariationStruct )
}

// from market to stocks (passando per StocksMng.ol)
interface MarketToStockCommunicationInterface {
// TODO: si vedano gli specifici todo all'interno di Stock.ol in relazione alle operazioni indicate
// (in sintesi dobbiam capire cosa / se / come struttura la response)
// messo boolean come response
    RequestResponse: buyStock( string )( bool ) throws StockUnknownException( StockNameExceptionType )
    RequestResponse: sellStock( string )( bool ) throws StockUnknownException( StockNameExceptionType )
    RequestResponse: infoStockAvailability( string )( int )
}
