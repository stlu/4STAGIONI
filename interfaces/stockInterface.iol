type Stocks: void {
    .stock[0,*]: StockSubStruct
}

type StockSubStruct: void {
    .static: StockStaticStruct
    .dynamic: StockDynamicStruct
}

// informazioni caricate dal file di configurazione xml (l'attributo "filename" è aggiunto a runtime)
type StockStaticStruct: void {
    .filename: string
    .name: string
    .info: void {
        .availability: int
        .totalPrice: double
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
    .totalPrice: double
}

// struttura dati utilizzata dallo stock per comunicare al market la variazione di produzione / deperimento
type StockVariationStruct: void {
    .name: string
    .variation: double
}

// interfaccia di comunicazione con ciascuna stock instance dinamicamente allocata (ed embeddata) all'interno di StocksMng.ol
interface StockInstanceInterface {
    RequestResponse: start( StockSubStruct )( void )
    RequestResponse: buyStock( void )( bool )
    RequestResponse: sellStock( void )( bool )
    RequestResponse: infoStockAvailability( void )( int )
}

// from stocks to market
interface StockToMarketCommunicationInterface {
    RequestResponse: registerStock( StockRegistrationStruct )( bool ) throws StockDuplicatedException( StockNameExceptionType )

    OneWay: addStock( StockVariationStruct )
    OneWay: destroyStock( StockVariationStruct )
}

// from market to stocks (passando per StocksMng.ol)
interface MarketToStockCommunicationInterface {
    RequestResponse: buyStock( string )( bool ) throws  StockUnknownException( StockNameExceptionType )
                                                        StockAvailabilityException( StockNameExceptionType )
    RequestResponse: sellStock( string )( bool ) throws StockUnknownException( StockNameExceptionType ) 
    RequestResponse: infoStockAvailability( string )( int ) throws StockUnknownException( StockNameExceptionType )
}