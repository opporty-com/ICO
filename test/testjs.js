var assert = require('assert');
var OpportyToken = artifacts.require('./OpportyToken.sol');
var Escrow = artifacts.require('./Escrow.sol');

contract('Test', function(accounts)   {

  // ************************************
  // Токен должен создаваься и деплоиться
  // ************************************
  it('should test that the Token contract can be deployed', function(done){
      OpportyToken.new().then(function(instance){
        assert.ok(instance.address);
      }).then(done);
  });

  // ************************************
  // Можно подтвержать пересылку токенов (ERC20)
  // ************************************
  it('should return the correct allowance amount after approval', async function() {
    let token = await OpportyToken.new();
    await token.approve(accounts[1], 100);
    let allowance = await token.allowance(accounts[0], accounts[1]);

    assert.equal(allowance, 100);
  });

  // ************************************
  // Тест который проверяет пересылку токенов и получение баланса (ERC20)
  // ************************************
  it('should return correct balances after transfer', async function() {
    let token = await OpportyToken.new();
    await token.transfer(accounts[1], 20);
    let balance0 = await token.balanceOf(accounts[0]);
    assert.equal(balance0, 9980);

    let balance1 = await token.balanceOf(accounts[1]);
    //console.log(balance1);
    assert.equal(balance1, 20);
  });

  // ************************************
  // Тест который проверяет что нельзя переслать больше чем есть на счету (ERC20)
  // ************************************
  it('should throw an error when trying to transfer more than balance', async function() {
    let token = await OpportyToken.new();
    try {
      await token.transfer(accounts[1], 100001);
      assert.fail('should have thrown before');
    } catch(error) {
      assert.notEqual(error.message.search('invalid opcode'), -1, 'Invalid opcode error must be returned');
    }
  });


  // ************************************
  // Тест который проверяет что создается успешно созданный нами контракт
  // ************************************
  it('should create escrow instances', async function() {
    let token = await OpportyToken.new();
    assert.ok(token.address);
    let escrow = await Escrow.new(token.address);
    assert.ok(escrow.address);
  });

  // ************************************
  // Тест который проверяет что можно успешно добавить проект в блокчейн
  // ************************************
  it('should create project in escrow', async function() {

    let token = await OpportyToken.new();
    let escrow = await Escrow.new(token.address);

    let trans = await escrow.addProject(1, "Project One", accounts[1], 1, 1);
    const {logs} = await escrow.addProject(2, "Project Two", accounts[1], 1, 1);
    const event = logs.find(e => e.event === 'ProjectAdded');

    assert.ok(event, "event ProjectAdded should exists");
    assert.equal(event.args.projectID.valueOf(), 1, "id should be 1");

  });
  
  // ************************************
  // Тест который проверяет что за проект может платить только клиент
  // ************************************
  it('should pay only client', async function() {

    let token = await OpportyToken.new();
    let escrow = await Escrow.new(token.address);
    let trans = await escrow.addProject(1,"Project One", accounts[1], 1, 1);
    const {logs} = await escrow.addProject(2,"Project Two", accounts[1], 1, 1);

    try {
      await escrow.payFor.sendTransaction(1, {value: web3.toWei(1), from:accounts[1] } );
    } catch (error) {
      assert.notEqual(error.message.search('invalid opcode'), -1, 'Invalid opcode error must be returned');
    }

  });

  // ************************************
  // Тест который проверяет что за проект можно заплатить этером и что меняется статус проекта
  // ************************************
  it('should fund be transfered', async function() {

    let token = await OpportyToken.new();
    let escrow = await Escrow.new(token.address);
    let trans = await escrow.addProject(1,"Project One", accounts[1], 1, 1, {from:accounts[0]});
    let trans2 = await escrow.addProject(2,"Project Two", accounts[1], 1, 1, {from:accounts[0]});

    const {logs} = await escrow.payFor( 0, {value: web3.toWei(1,"ether") , from:accounts[0]}   );

    const event = logs.find(e => e.event === 'FundTransfered');

    assert.ok(event, "event FundTransfered should exists");

    const event2 = logs.find(e => e.event === 'ChangedProjectStatus');
    assert.ok(event2, "event ChangedProjectStatus should exists");

  });

  // ************************************
  // Тест который проверяет что правильно возвращается флаг прихода дедлайна
  // ************************************
  it('should returns correct deadline flag', async function() {

    let token = await OpportyToken.new();
    var escrow = await Escrow.new(token.address);
    let trans = await escrow.addProject(1,"Project One", accounts[1], 1, 1, {from:accounts[0]});
    let trans2 = await escrow.addProject(2,"Project Two", accounts[1], 0, 1, {from:accounts[0]});

    const {logs} = await escrow.payFor( 0, {value: web3.toWei(1,"ether") , from:accounts[0]}   );

    let deadline1 = await escrow.isDeadline.call(0);

    assert.equal(deadline1, false, "deadline 1  should be false");
    var obj = await new Promise(function(resolve, reject) {
      setTimeout( () => {
        escrow.isDeadline.call(1).then(function(data){
            assert.equal(data, true, "deadline 2  should be true");
            resolve();
          });
      } , 1000 );
    });

    return obj;
  });
  // ************************************
  // Тест, который проверяет что исполнителем можно создать отчет и сменить статус на "проект выполнен"
  // ************************************
  it('should successfully provide report and complete work', async function() {

    let token = await OpportyToken.new();
    var escrow = await Escrow.new(token.address);
    let trans = await escrow.addProject(1,"Project", accounts[1], 0, 1, {from:accounts[0]});
    await escrow.payFor( 0, {value: web3.toWei(1,"ether") , from:accounts[0]}   );

    var obj = await new Promise(function(resolve, reject) {
      setTimeout( () => {
        escrow.isDeadline.call(0).then(function(data){
              assert.equal(data, true, "deadline 2  should be true");

              escrow.workDone(0,"report: http://secure.link/1.png", 1, {from:accounts[1]}).then(function(data){
                const {logs} = data;
                const event = logs.find(e => e.event === 'ChangedProjectStatus');

                assert.ok(event, "event ChangedProjectStatus should exists");
                resolve();
              });

          });
      } , 1000 );
    });

    return obj;
  });

  // ************************************
  // Тест, который проверяет что можно забраковать отчет, проголосовать судьями, и вывести деньги исполнителем
  // ************************************
  it('should successfully claim report and withdraw money after voting', async function() {

    let token = await OpportyToken.new();
    var escrow = await Escrow.new(token.address);
    let trans = await escrow.addProject(1,"Project", accounts[1], 0, 1, {from:accounts[0]});
    await escrow.payFor( 0, {value: web3.toWei(1,"ether") , from:accounts[0]}   );

    var obj = await new Promise(function(resolve, reject) {
      setTimeout( () => {
        escrow.isDeadline.call(0).then(function(data){
              escrow.workDone(0,"report: http://secure.link/1.png", 1, {from:accounts[1]}).then(function(d){

                escrow.claimWork(0, 2, 0).then(function(data){

                  const {logs} = data;
                  const event = logs.find(e => e.event === 'ChangedProjectStatus');
                  assert.ok(event, "event ChangedProjectStatus should exists");

                  escrow.vote(0, true, { from:accounts[2] }).then(function(data2) {
                    const {logs} = data2;
                    const event = logs.find(e => e.event === 'Voted');
                    assert.ok(event, "event Voted should exists");
                    escrow.vote(0, true, { from:accounts[3] }).then(function(data3) {
                      escrow.safeWithdrawal(0, {from:accounts[1]}).then(function(data4) {
                        const {logs} = data4;
                        const event = logs.find(e => e.event === 'FundTransfered');
                        assert.ok(event, "event FundTransfered should exists");
                        const event2 = logs.find(e => e.event === 'FundTransfered');
                        assert.ok(event2, "event ChangedProjectStatus should exists");
                        resolve();
                      })
                    });
                  })
                })
              });
          });
      } , 1000 );
    });

    return obj;
  });

});
