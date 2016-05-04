include "../config/constants.iol"
include "file.iol"
include "../interfaces/stockInterface.iol"
include "../interfaces/playerInterface.iol"

include "console.iol"
include "time.iol"
include "string_utils.iol"



outputPort MarketToStockCommunication { // utilizzata dal market per inviare richieste agli stock
    Location: "socket://localhost:8000"
    Protocol: sodep
    Interfaces: MarketToStockCommunicationInterface
}

inputPort StockToMarketCommunication { // utilizzata dagli stock per inviare richieste al market
    Location: "socket://localhost:8001"
    Protocol: sodep
    Interfaces: StockToMarketCommunicationInterface
}

inputPort PlayerToMarketCommunication { // utilizzata dai player per inviare richieste al market
    Location: "socket://localhost:8002"
    Protocol: sodep
    Interfaces: PlayerToMarketCommunicationInterface
}



execution { concurrent }

main {

/*
direttamente dalle specifiche del progetto
"registrarsi presso il Market. Gli Stocks si registrano presso il Market col proprio nome (e.g., "Oro", "Grano", "Petrolio") 
e il proprio valore totale iniziale."

ricorda la composizione della struttura registeredStocks (su cui è applicabile il dynamic lookup)
registeredStocks.( stockName )[ 0 ].price

ricorda la composizione della struttura dati con la quale lo stock effettua l'operazione di registrazione
newStock.name
newStock.price
*/

// operazione esposta agli stocks sulla porta 8001, definita nell'interfaccia StockToMarketCommunicationInterface
    [ registerStock( newStock )( response ) {

// dynamic lookup rispetto alla stringa newStock.name
        if ( ! is_defined( global.registeredStocks.( newStock.name )[ 0 ] )) {
            global.registeredStocks.( newStock.name )[ 0 ].price = newStock.price;

            valueToPrettyString@StringUtils( newStock )( result );
            println@Console( "\nMarket@registerStock, newStock:" + result )()

        };
// else    
// todo: lanciare un fault, uno stock con lo stesso nome è già registrato al market
// (caso praticamente impossibile visto che StocksDiscoverer presta particolare attenzione al parsing dei nomi dei nuovi stock)

        response = "done"

    } ] { nullProcess }



// operazione esposta ai players sulla porta 8003, definita nell'interfaccia PlayerToMarketCommunicationInterface
// è tutto assolutamente da implementare!
    [ buyStock( stockName )( response ) {
        if ( is_defined( global.registeredStocks.( stockName )[ 0 ] )) {
            buyStock@MarketToStockCommunication( stockName )( response );
            println@Console( response )()
        }
    } ] { nullProcess }



    [ sellStock( stockName )( response ) {
        if ( is_defined( global.registeredStocks.( stockName )[ 0 ] )) {
            sellStock@MarketToStockCommunication( stockName )( response );
            println@Console( response )()
        }
    } ] { nullProcess }    
}
