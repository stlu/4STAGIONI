include "../config/config.iol"
include "file.iol"
include "../behaviour/stockInterface.iol"

include "console.iol"
include "string_utils.iol"

// StocksMng.ol espone una sola operazione al launcher, ovvero quella di discovering, dalla quale scaturisce la creazione
// dinamica delle varie stock instances
outputPort StocksMng { 
	Interfaces: StocksLauncherInterface
}

embedded {
	Jolie:
		"../embeddedService/StocksMng.ol" in StocksMng
}

main {

	install(
//				default => nullProcess, // catch all exceptions
				
				// up to date
				StocksDiscovererFault => println@Console( main.StocksDiscovererFault.msg )(),

				IOException => throw( IOException ),
				FileNotFound => throw( FileNotFound )
			);

	discover@StocksMng( )( )
}