pragma solidity ^0.4.15;

import "./OpportyToken.sol";

contract owned {
    address public owner;

    function owned() {
        owner = msg.sender;
    }

    modifier onlyOwner {
        require (msg.sender == owner);
        _;
    }

    function transferOwnership(address newOwner) onlyOwner {
        owner = newOwner;
    }
}

contract Escrow is owned {
  //статус проекта
  enum Status { NEW, PAYED, WORKDONE, CLAIMED, CLOSED }

  //статус выполнения проекта исполниетелем
  enum WorkStatus {NEW, STARTED, FULLYDONE, PARTIALLYDONE }

  //адрес откуда брать токены
  address tokenHolder = 0x08990456DC3020C93593DF3CaE79E27935dd69b9;

  // модификатор, который позволяет выполнять транзакция только владельцами токенов
  modifier onlyShareholders {
      require (token.balanceOf(msg.sender) > 0);
      _;
  }

  // модификатор, который позволяет выполнять транзакцию только после дедлайна
  modifier afterDeadline(uint idProject)
  {
    Project memory project = projects[idProject];
    require (now > project.deadline) ;
    _;
  }

  // модификатор, который позволяет выполнять транзакцию только клиентом
  modifier onlyClient(uint idProject) {
    Project memory project = projects[idProject];

    require (project.client == msg.sender);
    _;
  }

  // модификатор, который позволяет выполнять транзакцию только исполнителем
  modifier onlyPerformer(uint idProject) {
    Project memory project = projects[idProject];
    require (project.performer == msg.sender);
    _;
  }
  // структура что представляет проект в оппорти
  // TODO: уменьшить  размер  который будет занимать проект (uint => uint4 )
  struct Project {
    uint id;
    string  name;
    address client;
    address performer;
    uint deadline;
    uint sum;
    Status status;
    string report;
    WorkStatus wstatus;
    uint votingDeadline;
    uint numberOfVotes;
    uint totalVotesNeeded;
    bool withdrawed;
    Vote[] votes;
    mapping (address => bool) voted;
  }
  // один голос - структура
  struct Vote {
      bool inSupport;
      address voter;
  }
  //проект добавлен - событие
  event ProjectAdded(uint projectID, address performer,  string name,uint sum );
  //деньги переведены - событие
  event FundTransfered(address recipient, uint amount);
  //работа выполнена
  event WorkDone(uint projectId, address performer, WorkStatus status, string link);
  //проголосовано
  event Voted(uint projectID, bool position, address voter);
  //изменен статус проекта
  event ChangedProjectStatus(uint projectID, Status status);

  event log(string val);
  event loga(address addr);
  event logi(uint i);

  // токен для оплаты
  OpportyToken token;

  // массив проектов
  Project[] projects;


  // количество проектов
  uint public numProjects;

  function Escrow(address tokenUsed)
  {
    token = OpportyToken(tokenUsed);
  }

  function getNumberOfProjects() constant  returns(uint)
  {
    return numProjects;
  }

  // добавить проект
  // idExternal - id в опорти
  // name название
  // performer - исполнитель
  // duration - сколько до дедлайна
  // sum - сколько вносить для активации (cумма в этерах)
  function addProject(uint idExternal, string name, address performer, uint durationInMinutes, uint sum)
     returns (uint projectId)
  {
    projectId = projects.length++;
    Project storage p = projects[projectId];
    p.id = idExternal;
    p.name = name;
    p.client = msg.sender;
    p.performer = performer;
    p.deadline = now + durationInMinutes * 1 minutes;
    p.sum = sum * 1 ether;
    p.status = Status.NEW;

    ProjectAdded(projectId, performer, name, sum);
    return projectId;
  }


  // получить статус
  // надо сделать константной наверное
  function getStatus(uint idProject) returns (uint t) {
    Project memory p = projects[idProject];
    return uint(p.status);
  }

  // пришел ли дедлайн
  // надо сделать константной наверное
  function isDeadline(uint idProject)  returns (bool f) {
      Project memory p = projects[idProject];

      if (now >= p.deadline) {
        return true;
      } else {
        return false;
      }
  }
  // внести оплату клиентом за проект
  // возвращает флаг тру в случае успеха
  function payFor(uint idProject) payable onlyClient(idProject) returns (bool) {
    Project storage project = projects[idProject];

    uint price = project.sum;

    require (project.status == Status.NEW);
    if (msg.value >= price) {
      project.status = Status.PAYED;
      FundTransfered(this, msg.value);
      ChangedProjectStatus(idProject, Status.PAYED);
      return true;
    } else {
      revert();
    }
  }
  // оплата в токенах
  function payByTokens(uint idProject) onlyClient(idProject) onlyShareholders {
    Project storage project = projects[idProject];
    require (project.sum <= token.balanceOf(project.client));
    require (token.transferFrom(project.client, tokenHolder, project.sum));

    ChangedProjectStatus(idProject, Status.PAYED);
  }
  // работа сделана исполнителем дать отчет и статус - до конца или нет
  function workDone(uint idProject, string report, WorkStatus status) onlyPerformer(idProject) afterDeadline(idProject) {
    Project storage project = projects[idProject];
    require (project.status == Status.PAYED);

    project.status = Status.WORKDONE;
    project.report = report;
    project.wstatus = status;

    WorkDone(idProject, project.performer, project.wstatus, project.report);
    ChangedProjectStatus(idProject, Status.WORKDONE);
  }
  // принять работу - только клиентом
  function acceptWork(uint idProject) onlyClient(idProject) afterDeadline(idProject) {
    Project storage project = projects[idProject];
    require (project.status == Status.WORKDONE);
    project.status = Status.CLOSED;
    ChangedProjectStatus(idProject, Status.CLOSED);
  }
  // жалоба - клиентом или кем то другим (?)
  // numberOfVoters - количество судей
  // debatePeriod - время для голосования
  function claimWork(uint idProject, uint numberOfVoters, uint debatePeriod) afterDeadline(idProject) {
    Project storage project = projects[idProject];
    require (project.status == Status.WORKDONE);
    project.status = Status.CLAIMED;
    project.votingDeadline = now + debatePeriod * 1 minutes;
    project.totalVotesNeeded = numberOfVoters;
    ChangedProjectStatus(idProject, Status.CLAIMED);
  }

  // голосование  - клиентом или кем то другим (?)
  // supportsProject - поддержать/нет
  function vote(uint idProject, bool supportsProject)
        returns (uint voteID)
  {
        Project storage p = projects[idProject];
        require(p.voted[msg.sender] != true);
        require(p.status == Status.CLAIMED);
        require(p.numberOfVotes < p.totalVotesNeeded);
        require(now >= p.votingDeadline );

        voteID = p.votes.length++;
        p.votes[voteID] = Vote({inSupport: supportsProject, voter: msg.sender});
        p.voted[msg.sender] = true;
        p.numberOfVotes = voteID + 1;
        Voted(idProject,  supportsProject, msg.sender);
        return voteID;
  }

  // safeWithdrawal - получение денег исполнителем / получить клиентом денег в этерах после невыполнения
  function safeWithdrawal(uint idProject) afterDeadline(idProject)
  {
      Project storage p = projects[idProject];

      //если статус закрыто или жалоба и не было вывод то продолжаем
      require(p.status == Status.CLAIMED || p.status == Status.CLOSED && !p.withdrawed);

      // если проект закрыт
      if (p.status == Status.CLOSED) {
        // и выполняется транзакция исполнителем
        // и он еще не снимал денег
        // отсылаем ему сумму с контракта
        if (msg.sender == p.performer && !p.withdrawed && msg.sender.send(p.sum) ) {
          FundTransfered(msg.sender, p.sum);
          p.withdrawed = true;
        } else {
          // иначе отменяем
          revert();
        }
      } else {
        // статус жалобы
        uint yea = 0;
        uint nay = 0;
        // считаем голоса
        for (uint i = 0; i <  p.votes.length; ++i) {
            Vote storage v = p.votes[i];

            if (v.inSupport) {
                yea += 1;
            } else {
                nay += 1;
            }
        }
        // если уже время голосования закончилось
        if (now >= p.votingDeadline) {
          // если транзакция делается испольнителем и количество голосов равно нужным
          if (msg.sender == p.performer && p.numberOfVotes >= p.totalVotesNeeded ) {
            // количество подтверждений больше ине было вывода - выводим с контракта
            if (yea>nay && !p.withdrawed && msg.sender.send(p.sum)) {
              FundTransfered(msg.sender, p.sum);
              p.withdrawed = true;
              p.status = Status.CLOSED;
              //меняем статус проекта
              ChangedProjectStatus(idProject, Status.CLOSED);
            }
          }
      // если транзакция делается клиентом
          if (msg.sender == p.client) {
            // и исполнитель не набрал голосов и клиент не выводил денег то клиенту отслыаем
            if (nay>=yea && !p.withdrawed &&  msg.sender.send(p.sum)) {
              FundTransfered(msg.sender, p.sum);
              p.withdrawed = true;
              p.status = Status.CLOSED;
              // меняем статус проекта
              ChangedProjectStatus(idProject, Status.CLOSED);
            }
          }
        } else {
          //отменяем вывод иначе
          revert();
        }
      }
  }

  // вывод в токенах по завершению
  function safeWithdrawalTokens(uint idProject) afterDeadline(idProject)
  {
    Project storage p = projects[idProject];
    require(p.status == Status.CLAIMED || p.status == Status.CLOSED && !p.withdrawed);

    if (p.status == Status.CLOSED) {

      if (msg.sender == p.performer && token.transfer(p.performer, p.sum) && !p.withdrawed) {
        FundTransfered(msg.sender, p.sum);
        p.withdrawed = true;
      } else {
        revert();
      }
    }
  }
}
