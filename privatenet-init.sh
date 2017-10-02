# Source author: https://gist.github.com/martinhbramwell/106709bde2ddd456c90599e4a3477615
#!/usr/bin/env bash
set -e;
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~";


declare COINBASE="";
declare MAIN_ACCOUNTS=();
declare BALANCE=0;
declare COL_MAIN_ACCOUNT=5;
declare WORK_DIR=$(echo | pwd);
declare NETWORK_ID=58545;
declare NODE_DIR="ethernode";
declare PASSWORD="123123123";
declare START_BALANCE="0x1337000000000000000000";#23229320 #$(( 1 * (10**18) ));


declare -A SHELLVARS;
declare SHELLVARNAMES=();

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#  addShellVar -- add a definition to the list of required shell variables
#
function addShellVar() {

  declare -A SHELLVAR;

  SHELLVARNAMES+=($1);
  SHELLVAR['LONG']=$2;
  SHELLVAR['SHORT']=$3;
  SHELLVAR['VAL']=$4;
  eval $1=$4;
  for key in "${!SHELLVAR[@]}"; do
    SHELLVARS[$1,$key]=${SHELLVAR[$key]};
  done

};

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#  Build shell variables definitions
#
# PREPARE ALL NEEDED SHELL VARIABLES BELOW THIS LINE
# EXAMPLE
# addShellVar 'NAME' \
#             'LONG' \
#             'SHORT' \
#             'VAL';

addShellVar 'DROP_DAGS' \
            'You want to delete the DAG file (y/n) :: ' \
            'Delete DAG file (y/n) : ${DROP_DAGS} ' \
            'n';

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#  loadShellVars -- get shell variables from file, if exists
#
function loadShellVars() {

  for varkey in "${!SHELLVARNAMES[@]}"; do
    X=${SHELLVARNAMES[$varkey]};
    SHELLVARS["${X},VAL"]=${!X};
    eval "export ${SHELLVARNAMES[$varkey]}='${SHELLVARS[${SHELLVARNAMES[$varkey]},VAL]}'";
  done

}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#  askUserForParameters -- iterate a list of shell vars, prompting for setting
#
function askUserForParameters()
{

  declare -a VARS_TO_UPDATE=("${!1}");

  CHOICE="n";
  while [[ ! "X${CHOICE}X" == "XyX" ]]
  do
    ii=1;
    for varkey in "${VARS_TO_UPDATE[@]}"; do
      eval  "printf \"\n%+5s  %s\" $ii \"${SHELLVARS[${varkey},SHORT]}\"";
#      eval   "echo $ii/. -- ${SHELLVARS[${varkey},SHORT]}";
      ((ii++));
    done;

    echo -e "\n\n";

    read -ep "Is this correct? (y/n/q) ::  " -n 1 -r USER_ANSWER
#    USER_ANSWER='q';
    CHOICE=$(echo ${USER_ANSWER:0:1} | tr '[:upper:]' '[:lower:]')
    if [[ "X${CHOICE}X" == "XqX" ]]; then
      echo "Skipping this operation."; exit 1;
    elif [[ ! "X${CHOICE}X" == "XyX" ]]; then

      for varkey in "${VARS_TO_UPDATE[@]}"; do
        read -p "${SHELLVARS[${varkey},LONG]}" -e -i "${!varkey}" INPUT
        if [ ! "X${INPUT}X" == "XX" ]; then eval "${varkey}=\"${INPUT}\""; fi;
      done;

    fi;
    echo "  "
  done;

  return;

};

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#  aptNotYetInstalled -- check if installation is needed
#
function aptNotYetInstalled() {

  set +e;
  return $(dpkg-query -W --showformat='${Status}\n' $1 2>/dev/null | grep -c "install ok installed");
  set -e;

}


# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#  installDependencies -- Install Ethereum and related dependencies.
#
function installDependencies()
{
  echo -e "\n ~~ Preparing dependency installation";
  if aptNotYetInstalled "ethereum"; then

    sudo apt-get -q -y install software-properties-common wget;
    # # sudo add-apt-repository -y ppa:ethereum/ethereum;
    sudo add-apt-repository -y ppa:ethereum/ethereum-dev;
    sudo apt-get update -qq -y;
    sudo apt-get install -q -y ethereum;
    echo " ~~~~ Complete dependency installation 'ethereum";
  else
    echo " ~~~~ Skipped dependency installation 'ethereum";
  fi

  if aptNotYetInstalled "ethereumwallet"; then
    wget https://github.com/ethereum/mist/releases/download/v0.9.1/Ethereum-Wallet-linux64-0-9-1.deb;
    sudo dpkg -i Ethereum-Wallet-linux64-0-9-1.deb
    rm Ethereum-Wallet-linux64-0-9-1.deb
    echo " ~~~~ Complete dependency installation 'ethereumwallet";
  else
    echo " ~~~~ Skipped dependency installation 'ethereumwallet";
  fi

};

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#  prepareWorkingFilesStructure -- Prepare a consistent file layout
#
function prepareWorkingFilesStructure()
{

  echo -e "\n ~~ Preparing work directories in ${WORK_DIR}";
  #geth removedb --datadir ${WORK_DIR}/${NODE_DIR}


  if [[ -d ${WORK_DIR}/${NODE_DIR} ]]; then
    rm -rf ${WORK_DIR}/${NODE_DIR}/*
    echo -e " ~~~~ Clean ${WORK_DIR}/${NODE_DIR}/";
  else
    mkdir -p ${WORK_DIR}/${NODE_DIR};
    echo -e " ~~~~ Create ${WORK_DIR}/${NODE_DIR}";
  fi


  if [[ -f ${WORK_DIR}/${NODE_DIR}/geth.log ]]; then
    echo "" > ${WORK_DIR}/${NODE_DIR}/geth.log;
    echo -e " ~~~~ Clear ${WORK_DIR}/${NODE_DIR}/geth.log";
  else
    touch ${WORK_DIR}/${NODE_DIR}/geth.log;
    echo -e " ~~~~ Create ${WORK_DIR}/${NODE_DIR}/geth.log";
  fi


  if [[ -d ~/.ethash ]]; then
    if [[ ${DROP_DAGS} == "y" ]]; then
      echo -e " ~~~~ Clean DAG files ~/.ethash";
      rm -fr ~/.ethash/*;
    fi;
  fi

};



# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#  makeInitialCoinBaseAccount -- create the account to write into the Genesis file
#
function makeInitialCoinBaseAccount()
{

  if [[ ! ${COINBASE} =~ ^"0x"[a-f0-9]{40}$ ]]; then

    echo -e "\n ~~ Create base account " ;
    declare ACCT=$(geth  --datadir "${WORK_DIR}/${NODE_DIR}" --verbosity 0  --password <(echo  ${PASSWORD}) account new);
    # echo Account = ${ACCT};
    declare ACCT_NO=$(echo ${ACCT}  | cut -d "{" -f 2 | cut -d "}" -f 1);
    # echo Account number = ${ACCT_NO};
    COINBASE="0x${ACCT_NO}";
    echo " ~~~~ ( Account number : ${COINBASE} )" ;

  fi;

};


# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#  makeMainAccount -- create the account to write into the Genesis file
#
function makeMainAccount()
{
  echo -e "\n ~~ Create main account " ;

  for (( i=1; i<=COL_MAIN_ACCOUNT; i++ )) do
    declare ACCT=$(geth  --datadir "${WORK_DIR}/${NODE_DIR}" --verbosity 0  --password <(echo  ${PASSWORD}) account new);
    declare ACCT_NO=$(echo ${ACCT}  | cut -d "{" -f 2 | cut -d "}" -f 1);
    MAIN_ACCOUNTS[i]="0x${ACCT_NO}";
    echo " ~~~~ ( Account number : ${MAIN_ACCOUNTS[i]} )" ;
  done

};


# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#  configureGenesisFile -- Add coin base account preallocation to Genesis file.
#
function configureGenesisFile()
{
  echo -e "\n ~~ Configure Genesis File " ;

  cp ${WORK_DIR}/genesis.json ${WORK_DIR}/${NODE_DIR}/genesis.json
  declare ALLOC="\"${COINBASE}\": { \"balance\": \"${START_BALANCE}\" }";
  # echo Alloc = ${ALLOC};

  echo -e " ~~~~ Update the Genesis file with preallocation to coin base account." ;
  sed -i -e "s/\"alloc\": {}/\"alloc\": { ${ALLOC} }/g" ${WORK_DIR}/${NODE_DIR}/genesis.json;

};

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#  initializeBlockChain -- builds the blockchain from the genesis block
#
function initializeBlockChain()
{

  echo -e "\n ~~ Initialize the Block Chain's foundation block" ;
  geth --datadir "${WORK_DIR}/${NODE_DIR}" --networkid ${NETWORK_ID} --verbosity 3 init ${WORK_DIR}/${NODE_DIR}/genesis.json

};

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#  createDAGfile -- Builds the Dagger-Quasimodo file, if not exists
#
function createDAGfile()
{

  if [ ! -f ~/.ethash/full-R23-290decd9548b62a8 ]; then
    echo -e "\n ~~ Creating DAG file.";
    mkdir -p ~/.ethash;
    geth  --datadir "${WORK_DIR}/${NODE_DIR}" --networkid ${NETWORK_ID} --verbosity 3  makedag 0 ~/.ethash;
  fi;

};

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#  getBaseAccountBalance -- If eth.account[0] exists, get it into a shell variable
#
function getBaseAccountBalance()
{

  echo -e "\n ~~ Try to read base account balance";
  if [[ ${COINBASE} =~ ^"0x"[a-f0-9]{40}$ ]]; then
    echo " ~~~~ Getting balance of base account : ${COINBASE} )" ;
    BALANCE=$(geth --datadir "${WORK_DIR}/${NODE_DIR}" --networkid ${NETWORK_ID} --verbosity 0 --exec 'web3.fromWei(eth.getBalance(eth.accounts[0]), "ether")' console);
    echo " ~~~~ Current coin base balance : ${BALANCE} Eth";
  else
    echo " !!!! Found no coin base account." ;
    exit 1;
  fi;

};


# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#  transferEthToMainAccounts
#
function transferEthToMainAccounts()
{
  echo -e "\n ~~ transfer Eth To Main Accounts";
  if [[ ${BALANCE} ]]; then

    for account in ${!MAIN_ACCOUNTS[*]}
    do

      declare ETH_VALUE=1000000;
      if [[ account -eq ${#MAIN_ACCOUNTS[@]} ]]; then
        ETH_VALUE=1
      fi;

      if [[ ${MAIN_ACCOUNTS[$account]} =~ ^"0x"[a-f0-9]{40}$ ]]; then
        echo " ~~~~ Account : ${MAIN_ACCOUNTS[$account]} Balance: ${ETH_VALUE}" ;
        STATUS=$(geth --datadir "${WORK_DIR}/${NODE_DIR}" --networkid ${NETWORK_ID} --verbosity 0 --exec "personal.unlockAccount(eth.coinbase, '${PASSWORD}', 0); eth.sendTransaction({from:eth.coinbase, to:'${MAIN_ACCOUNTS[$account]}', value: web3.toWei('${ETH_VALUE}', \"ether\")})" console);
        echo " ~~~~ Status : ${STATUS}";
      else
        echo " !!!! Found no coin base account." ;
        exit 1;
      fi;

    done

    echo -e "\n ~~ Start mining 10 block";
    STATUS=$(geth --datadir "${WORK_DIR}/${NODE_DIR}" --networkid ${NETWORK_ID} --verbosity 3 --exec "  miner.start(2); admin.sleepBlocks(10); miner.stop();" console);
    echo " ~~~~ Status mining : ${STATUS}";

  else
    echo "   ~ Skipped ' balance is ${BALANCE}.";
    exit 1;
  fi

};

CLEANER_PARMS=("DROP_DAGS");

declare PARM_NAMES=("${CLEANER_PARMS[@]}");

askUserForParameters PARM_NAMES[@];

loadShellVars;

prepareWorkingFilesStructure;
installDependencies;
makeInitialCoinBaseAccount;
configureGenesisFile;
initializeBlockChain;

createDAGfile;

BALANCE=0;
getBaseAccountBalance;

makeMainAccount;
transferEthToMainAccounts;


echo "";
echo "";
echo -e "\n      * * * Setup has Finished * * *  ";
echo -e "\n You are ready to start. Run ./privatenet-start.sh or the following command : ";
echo "";
echo geth --networkid ${NETWORK_ID} --nodiscover --datadir "${WORK_DIR}/${NODE_DIR}" --maxpeers=0 --ipcpath $HOME/.ethereum/geth.ipc --rpc --preload="privatenet-preload.js" console
echo "";
echo -e "\n ~~ To view accumulated ether, enter > web3.fromWei(eth.getBalance(eth.accounts[0]), \"ether\") ";
echo -e "\n ~~ unlock accoun in current session > personal.unlockAccount(eth.coinbase, '${PASSWORD}', 0) ";
echo -e "\n ~~ To start mining                  > miner.start(1) ";
echo -e "\n ~~ Then to pause mining             > miner.stop() ";
echo -e "\n ~~ Exit console and close ether     > exit ";
echo -e "\n ~~ To attach from another local terminal session, use :";
echo "";
echo geth --datadir "${WORK_DIR}/${NODE_DIR}" --networkid ${NETWORK_ID} attach ipc://$HOME/.ethereum/geth.ipc
echo "";
echo -e "\n ~~ CURRENT PARAMS";
echo -e " ~~~~ Base Account:          ${COINBASE}";
printf  ' ~~~~ Main Accounts:         %s\n' "${MAIN_ACCOUNTS[@]}";
echo -e " ~~~~ All Accounts Password: ${PASSWORD}";
echo "";
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~";

echo "Done.";
exit 0;