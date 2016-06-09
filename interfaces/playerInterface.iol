type InfoStockStruct: void {
    .name[0,*]: string
}

/*
 * Strutture del tipo di dato PlayerStatus e del tipo di dato stockQuantity
 * usato  per rappresentare una quantità di un certo stock posseduta dal player.
 */
type PlayerStatus: string {
    .ownedStock*: StockQuantity
    .liquidity: double
}

type StockQuantity: string {
    .quantity: int
}

/*
 * Struttura del tipo di dato Receipt, con il quale il market informa il player
 * dell'esito di una buy/sell e del prezzo al quale è avvenuta la transazione
 */
type Receipt: void {
    .stock: string
    .kind: int //Può essere solo +1 o -1
    .esito: bool
    .price: double //E' positivo o negativo a seconda del tipo di transazione
}

/*
* Struttura del tipo di dato TransactionRequest, contiene semplicemente
* il nome del Player richiedente e lo stock in questione
*/
type TransactionRequest: void {
    .player: string
    .stock: string
}

// eccezione lanciata da registerStock@Market qualora un player con lo stesso nome tenti nuovamente di registrarsi
// oppure, lanciata dalle operazioni buyStock e sellStock qualora il player non sia correttamente registrato
type PlayerNameExceptionType: void {
    .playerName: string
}

// eccezione lanciata all'interno delle operazioni buyStock e sellStock qualora la liquidità del player
// sia insufficiente per completare la transazione
type TransactionExceptionType: void {
    .stockName: string
    .currentLiquidity: double
    .neededLiquidity: double
}

interface PlayerToMarketCommunicationInterface {
    RequestResponse: registerPlayer( string )( PlayerStatus ) throws PlayerDuplicatedException( PlayerNameExceptionType )
    RequestResponse: buyStock( TransactionRequest )( Receipt ) throws   StockUnknownException( StockNameExceptionType )
                                                                        PlayerUnknownException( PlayerNameExceptionType )
                                                                        StockAvailabilityException( StockNameExceptionType )
                                                                        InsufficientLiquidityException( TransactionExceptionType )
    RequestResponse: sellStock( TransactionRequest )( Receipt ) throws  StockUnknownException( StockNameExceptionType )
                                                                        PlayerUnknownException( PlayerNameExceptionType )
                                                                        NotOwnedStockException ( StockNameExceptionType )
    RequestResponse: infoStockList( string )( InfoStockStruct ) throws StockUnknownException( StockNameExceptionType )
    RequestResponse: infoStockPrice( string )( double ) throws StockUnknownException( StockNameExceptionType )
    RequestResponse: infoStockAvailability( string )( double ) throws StockUnknownException( StockNameExceptionType )
}