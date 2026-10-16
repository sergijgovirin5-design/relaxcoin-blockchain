using System;
using System.Collections.Generic;
using System.Security.Cryptography;
using System.Text;
using Newtonsoft.Json;

public class Transaction
{
    public string Sender { get; set; }
    public string Recipient { get; set; }
    public double Amount { get; set; }
    public string Memo { get; set; }
}

public class Block
{
    public int Index { get; set; }
    public long Timestamp { get; set; }
    public List<Transaction> Transactions { get; set; }
    public string PreviousHash { get; set; }
    public int Nonce { get; set; }
    public string Hash { get; set; }

    public string CalculateHash()
    {
        string blockData = Index + Timestamp.ToString() + JsonConvert.SerializeObject(Transactions) + PreviousHash + Nonce;
        using (SHA256 sha256 = SHA256.Create())
        {
            byte[] bytes = sha256.ComputeHash(Encoding.UTF8.GetBytes(blockData));
            StringBuilder builder = new StringBuilder();
            foreach (byte b in bytes)
            {
                builder.Append(b.ToString("x2"));
            }
            return builder.ToString();
        }
    }
}

public class Blockchain
{
    public List<Block> Chain { get; set; } = new List<Block>();
    public List<Transaction> PendingTransactions { get; set; } = new List<Transaction>();
    public int Difficulty { get; set; } = 4;

    public Blockchain()
    {
        Chain.Add(CreateGenesisBlock());
    }

    public Block CreateGenesisBlock()
    {
        var block = new Block
        {
            Index = 0,
            Timestamp = DateTimeOffset.UtcNow.ToUnixTimeSeconds(),
            Transactions = new List<Transaction>(),
            PreviousHash = "0",
            Nonce = 0
        };
        block.Hash = block.CalculateHash();
        return block;
    }

    public Block GetLatestBlock()
    {
        return Chain[Chain.Count - 1];
    }

    public void AddTransaction(Transaction transaction)
    {
        PendingTransactions.Add(transaction);
    }

    public void MinePendingTransactions(string minerAddress)
    {
        var block = new Block
        {
            Index = Chain.Count,
            Timestamp = DateTimeOffset.UtcNow.ToUnixTimeSeconds(),
            Transactions = new List<Transaction>(PendingTransactions),
            PreviousHash = GetLatestBlock().Hash,
            Nonce = 0
        };
        ProofOfWork(block);
        Chain.Add(block);
        PendingTransactions = new List<Transaction>
        {
            new Transaction { Sender = "SYSTEM", Recipient = minerAddress, Amount = 1.0, Memo = "Mining reward" }
        };
    }

    public void ProofOfWork(Block block)
    {
        string target = new string('0', Difficulty);
        while (!block.Hash.StartsWith(target))
        {
            block.Nonce++;
            block.Hash = block.CalculateHash();
        }
    }

    public bool IsChainValid()
    {
        for (int i = 1; i < Chain.Count; i++)
        {
            var current = Chain[i];
            var previous = Chain[i - 1];
            if (current.Hash != current.CalculateHash()) return false;
            if (current.PreviousHash != previous.Hash) return false;
        }
        return true;
    }
}

public class Program
{
    public static void Main(string[] args)
    {
        var blockchain = new Blockchain();
        blockchain.AddTransaction(new Transaction { Sender = "miner1", Recipient = "worker1", Amount = 100.0, Memo = "Salary" });
        blockchain.MinePendingTransactions("miner1");

        ProcessCardPayment("4111111111111111", 150.0);
        PayoutSalary("worker1_wallet", 800.0);
        PayoutBusiness("business_wallet", 2000.0);

        Console.WriteLine("Chain valid: " + blockchain.IsChainValid());
    }

    public static void ProcessCardPayment(string cardNumber, double amount)
    {
        Console.WriteLine($"Visa/Mastercard payment processed: {amount} USD from {cardNumber}");
    }

    public static void PayoutSalary(string account, double amount)
    {
        Console.WriteLine($"Salary payout {amount} USD to {account}");
    }

    public static void PayoutBusiness(string account, double amount)
    {
        Console.WriteLine($"Business payout {amount} USD to {account}");
    }
}
