include "../config/config.iol"
include "../deployment/playerInterface.iol"

include "console.iol"
include "time.iol"

outputPort PlayerToMarketCommunication {
	Location: "socket://localhost:8002"
	Protocol: sodep
	Interfaces: PlayerToMarketCommunicationInterface
}

execution { single }

main {
	while ( true ) {
		buyStock@PlayerToMarketCommunication( "Oro" )( response ) |
		sellStock@PlayerToMarketCommunication( "Oro" )( response ) | 
		buyStock@PlayerToMarketCommunication( "Petrolio" )( response ) |
		sellStock@PlayerToMarketCommunication( "Petrolio" )( response ) |
		buyStock@PlayerToMarketCommunication( "Grano" )( response ) | 
		sellStock@PlayerToMarketCommunication( "Grano" )( response );

// boom boom boom every 3 second
		sleep@Time( 3000 )()
	}
}