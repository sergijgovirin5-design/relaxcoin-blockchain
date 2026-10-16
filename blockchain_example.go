package main

import (
    "crypto/sha256"
    "encoding/hex"
    "encoding/json"
    "errors"
    "fmt"
    "strconv"
    "time"
)

type Transaction struct {
    Sender    string  `json:"sender"`
    Recipient string  `json:"recipient"`
    Amount    float64 `json:"amount"`
    Memo      string  `json:"memo"`
}

type Block struct {
    Index        int           `json:"index"`
    Timestamp    int64         `json:"timestamp"`
    Transactions []Transaction `json:"transactions"`
    PreviousHash string        `json:"previous_hash"`
    Hash         string        `json:"hash"`
    Nonce        int           `json:"nonce"`
}

type Blockchain struct {
    Chain               []Block
    PendingTransactions []Transaction
    Difficulty          int
}

func calculateHash(block Block) string {
    record := strconv.Itoa(block.Index) + strconv.FormatInt(block.Timestamp, 10) + fmt.Sprintf("%v", block.Transactions) + block.PreviousHash + strconv.Itoa(block.Nonce)
    h := sha256.New()
    h.Write([]byte(record))
    return hex.EncodeToString(h.Sum(nil))
}

func createGenesisBlock() Block {
    block := Block{0, time.Now().Unix(), []Transaction{}, "0", "", 0}
    block.Hash = calculateHash(block)
    return block
}

func (bc *Blockchain) getLatestBlock() Block {
    return bc.Chain[len(bc.Chain)-1]
}

func (bc *Blockchain) AddTransaction(tx Transaction) error {
    if tx.Amount <= 0 {
        return errors.New("invalid transaction amount")
    }
    if tx.Sender == "" || tx.Recipient == "" {
        return errors.New("sender and recipient are required")
    }
    bc.PendingTransactions = append(bc.PendingTransactions, tx)
    return nil
}

func VerifyTransactionSignature(tx Transaction, signature string) bool {
    hashInput := fmt.Sprintf("%s:%s:%f", tx.Sender, tx.Recipient, tx.Amount)
    sum := sha256.Sum256([]byte(hashInput))
    return signature == hex.EncodeToString(sum[:])
}

func (bc *Blockchain) minePendingTransactions(minerAddress string) {
    block := Block{len(bc.Chain), time.Now().Unix(), bc.PendingTransactions, bc.getLatestBlock().Hash, "", 0}
    bc.proofOfWork(&block)
    bc.Chain = append(bc.Chain, block)
    bc.PendingTransactions = []Transaction{{"SYSTEM", minerAddress, 1.0, "block reward"}}
}

func (bc *Blockchain) proofOfWork(block *Block) {
    target := ""
    for i := 0; i < bc.Difficulty; i++ {
        target += "0"
    }
    for {
        block.Hash = calculateHash(*block)
        if block.Hash[:bc.Difficulty] == target {
            break
        }
        block.Nonce++
    }
}

func (bc *Blockchain) isChainValid() bool {
    for i := 1; i < len(bc.Chain); i++ {
        current := bc.Chain[i]
        previous := bc.Chain[i-1]
        if current.Hash != calculateHash(current) {
            return false
        }
        if current.PreviousHash != previous.Hash {
            return false
        }
    }
    return true
}

func processCardPayment(cardNumber string, amount float64) bool {
    fmt.Printf("Visa/Mastercard payment processed: %0.2f USD from %s\n", amount, cardNumber)
    return true
}

func payoutSalary(account string, amount float64) bool {
    fmt.Printf("Salary payout %0.2f USD to %s\n", amount, account)
    return true
}

func payoutBusiness(account string, amount float64) bool {
    fmt.Printf("Business payout %0.2f USD to %s\n", amount, account)
    return true
}

func main() {
    bc := Blockchain{[]Block{createGenesisBlock()}, []Transaction{}, 4}
    if err := bc.AddTransaction(Transaction{"miner1", "worker1", 100.0, "Salary"}); err != nil {
        panic(err)
    }
    bc.minePendingTransactions("miner1")
    processCardPayment("4111111111111111", 200.0)
    payoutSalary("worker1_wallet", 1200.0)
    payoutBusiness("business_wallet", 3000.0)
    fmt.Println("Chain valid:", bc.isChainValid())
}
