include "../config/config.iol"
include "file.iol"
include "../deployment/stockInterface.iol"

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

// In the `sequential` and `concurrent` cases, the behavioural definition inside the main procedure must be an input statement.
// mentre, nella modalità di default (single), posso inserire richieste a servizi
execution { single }

main {

	install(
//				default => nullProcess, // catch all exceptions
				
				// up to date
				StocksDiscovererFault => println@Console( main.StocksDiscovererFault.msg )(),

// todo: intercettare fault
				IOException => throw( IOException ),
				FileNotFound => throw( FileNotFound )
			);

// effettua un check alla ricerca di nuovi stock ogni 30 secondi
	discoveringInterval = 30000;
	discover@StocksMng( discoveringInterval )( )
}