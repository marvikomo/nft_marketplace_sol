const { ethers } = require("hardhat")

describe("NFTMarket", ()=>{
    it("should create and execute market sales", async()=>{
        const Market = await ethers.getContractFactory('NFTMarket')
        const market = await Market.deploy();
        const marketAddress = market.address;
        console.log(marketAddress)
        let listingPrice = await market.getListingPrice()
        listingPrice = listingPrice.toString()
        const auctionPrice = ethers.utils.parseUnits('1', 'ether')
        console.log('auc',auctionPrice)
        await market.createToken("https://www.mytokenlocation.com", auctionPrice, { value: listingPrice })
    
        await market.createToken("https://www.mytokenlocation2.com", auctionPrice, { value: listingPrice })

        const [_, buyerAddress] = await ethers.getSigners() //this gives array of addresses
        await market.connect(buyerAddress).createMarketSale(1, { value: auctionPrice })
        await market.connect(buyerAddress).resellToken(1, auctionPrice, { value: listingPrice })
        items = await market.fetchMarketItems()
        console.log(items)
    })
})