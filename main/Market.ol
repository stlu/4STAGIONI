include "../config/config.iol"
include "file.iol"
include "../behaviour/stockInterface.iol"

include "console.iol"
include "time.iol"

inputPort StockToMarketCommunication { // Stock.ol
	Location: "socket://localhost:8001"
	Protocol: sodep
	Interfaces: StockToMarketCommunicationInterface
}

outputPort MarketToStockCommunication { // StocksMng.ol
	Location: "socket://localhost:8000"
	Protocol: sodep
	Interfaces: MarketToStockCommunicationInterface
}

execution { concurrent }

main {	
	[ register ( request )( response ) {
		println@Console( "register@Market: " + request )();
		response = "";

// test only: non appena arriva una richiesta di registrazione, richiedo l'operazione buyStock a StocksMng che dovrà
// occuparsi di inoltrarla alla specifica istanza di stock identificata dallo stesso nome
// (occhio che non produce i risultati attesi poichè è lanciata una request-response prima del termina di quella invocata)
		buyStock@MarketToStockCommunication( request )( response );
		println@Console( "buyStock@StocksMng: " + response )()

	} ] { nullProcess }
}