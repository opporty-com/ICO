module.exports = function(callback) {
  
	

if (typeof web3 !== 'undefined') {

console.log(web3);

} else {
  // set the provider you want from Web3.providers
  web3 = new Web3(new Web3.providers.HttpProvider("http://localhost:8545"));

console.log(web3);
}


}
