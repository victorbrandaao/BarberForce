@isTest
public class AgendamentoTriggerTest {
  // 1. DATA FIXA: SEGUNDA-FEIRA às 10:00 (Para garantir que é dia útil)
  // Usamos isso para não depender do dia real que o teste roda
  static Datetime getDataSegundaFeira(Integer semanasParaFrente) {
    // 05/10/2026 é uma Segunda-feira.
    // Adicionamos semanas para variar as datas, mas manter o dia da semana.
    return Datetime.newInstance(2026, 10, 5, 10, 0, 0)
      .addDays(semanasParaFrente * 7);
  }

  @isTest
  static void testeCaminhoFeliz() {
    Contact cliente = new Contact(LastName = 'Cliente Feliz');
    insert cliente;

    Agendamento__c ag = new Agendamento__c();
    ag.Cliente__c = cliente.Id;
    ag.Data_Hora__c = getDataSegundaFeira(1); // Semana que vem

    System.Test.startTest();
    insert ag;
    System.Test.stopTest();

    System.assert(ag.Id != null, 'O agendamento deveria ter sido salvo.');
  }

  @isTest
  static void testeBloqueioPassado() {
    Contact cliente = new Contact(LastName = 'Cliente Passado');
    insert cliente;

    Agendamento__c ag = new Agendamento__c();
    ag.Cliente__c = cliente.Id;
    ag.Data_Hora__c = System.now().addDays(-1); // Ontem

    try {
      insert ag;
      System.assert(false, 'Deixou agendar no passado!');
    } catch (Exception e) {
      System.assert(
        e.getMessage().containsIgnoreCase('passado'),
        'Msg errada: ' + e.getMessage()
      );
    }
  }

  @isTest
  static void testeBloqueioFimDeSemana() {
    Contact cliente = new Contact(LastName = 'Cliente Domingo');
    insert cliente;

    // 04/10/2026 = Domingo
    Datetime domingo = Datetime.newInstance(2026, 10, 4, 10, 0, 0);

    Agendamento__c ag = new Agendamento__c(
      Cliente__c = cliente.Id,
      Data_Hora__c = domingo
    );

    try {
      insert ag;
      System.assert(false, 'Deixou agendar no Domingo!');
    } catch (Exception e) {
      System.assert(
        e.getMessage().containsIgnoreCase('fechados'),
        'Msg errada: ' + e.getMessage()
      );
    }
  }

  @isTest
  static void testeBloqueioDuplicidade() {
    Contact c1 = new Contact(LastName = 'Cliente 1');
    insert c1;
    Contact c2 = new Contact(LastName = 'Cliente 2');
    insert c2;

    Datetime dataComum = getDataSegundaFeira(2);

    // Agendamento 1 (Sucesso)
    insert new Agendamento__c(Cliente__c = c1.Id, Data_Hora__c = dataComum);

    // Agendamento 2 (Mesma hora -> Falha)
    Agendamento__c ag2 = new Agendamento__c(
      Cliente__c = c2.Id,
      Data_Hora__c = dataComum
    );

    try {
      insert ag2;
      System.assert(false, 'Deixou agendar horário duplicado!');
    } catch (Exception e) {
      System.assert(
        e.getMessage().containsIgnoreCase('indisponível'),
        'Msg errada: ' + e.getMessage()
      );
    }
  }

  @isTest
  static void testeLimitePorCliente() {
    // ESTE É O NOVO TESTE DO MAPA
    Contact cliente = new Contact(LastName = 'Cliente Fominha');
    insert cliente;

    // Cria 2 agendamentos futuros (Sucesso)
    Agendamento__c a1 = new Agendamento__c(
      Cliente__c = cliente.Id,
      Data_Hora__c = getDataSegundaFeira(3)
    );
    Agendamento__c a2 = new Agendamento__c(
      Cliente__c = cliente.Id,
      Data_Hora__c = getDataSegundaFeira(4)
    );
    insert new List<Agendamento__c>{ a1, a2 }; // Insere lista de uma vez

    // Tenta criar o 3º (Falha)
    Agendamento__c a3 = new Agendamento__c(
      Cliente__c = cliente.Id,
      Data_Hora__c = getDataSegundaFeira(5)
    );

    try {
      System.Test.startTest();
      insert a3;
      System.Test.stopTest();
      System.assert(false, 'Deixou criar o 3º agendamento!');
    } catch (Exception e) {
      // Verifica se a mensagem fala sobre "2 agendamentos"
      Boolean msgOk = e.getMessage().contains('2 agendamentos');
      System.assert(
        msgOk,
        'Msg esperada: limite de 2. Recebida: ' + e.getMessage()
      );
    }
  }
}
