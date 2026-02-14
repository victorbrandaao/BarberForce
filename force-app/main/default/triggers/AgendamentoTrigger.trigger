trigger AgendamentoTrigger on Agendamento__c(before insert, before update) {
  // VARIÁVEIS PARA AS REGRAS
  Set<Datetime> datasParaVerificar = new Set<Datetime>();
  Set<Id> idsDeClientes = new Set<Id>(); // Vamos usar para buscar o Nome e verificar limite

  // LOOP 1: COLETA E REGRAS BÁSICAS
  for (Agendamento__c a : Trigger.new) {
    if (a.Data_Hora__c != null) {
      // --- Regras de Validação (Passado / Fim de Semana) ---
      String diaSemana = a.Data_Hora__c.format('E');
      Integer hora = a.Data_Hora__c.hour();

      if (a.Data_Hora__c < System.now()) {
        a.addError('Não é permitido agendar para o passado.');
      } else if (
        diaSemana == 'Sat' ||
        diaSemana == 'Sun' ||
        hora < 9 ||
        hora >= 18
      ) {
        a.addError('Estamos fechados! (Seg-Sex, 09h-18h).');
      } else {
        // Coleta dados para processamento em lote
        datasParaVerificar.add(a.Data_Hora__c);
        if (a.Cliente__c != null) {
          idsDeClientes.add(a.Cliente__c);
        }
      }
    }
  }

  // --- LÓGICA 1: PREENCHER O NOME AUTOMÁTICO (CUSTOMIZAÇÃO QUE VOCÊ PEDIU) ---
  // Precisamos buscar o nome do contato no banco, pois na trigger só temos o ID
  if (!idsDeClientes.isEmpty()) {
    // Mapa para acessar o contato rapidamente pelo ID
    // Trazemos o Name (Nome Completo) para usar no rótulo
    Map<Id, Contact> mapContatos = new Map<Id, Contact>(
      [SELECT Id, Name FROM Contact WHERE Id IN :idsDeClientes]
    );

    // Consulta para verificar limite de agendamentos (Regra do Cliente Fominha)
    // Aproveitamos a mesma lista de IDs para otimizar
    List<Agendamento__c> agendamentosFuturos = [
      SELECT Cliente__c
      FROM Agendamento__c
      WHERE
        Cliente__c IN :idsDeClientes
        AND Data_Hora__c > :System.now()
        AND Id NOT IN :Trigger.new
    ];

    // Mapa para contar quantos agendamentos cada um tem
    Map<Id, Integer> contagemPorCliente = new Map<Id, Integer>();
    for (Agendamento__c ag : agendamentosFuturos) {
      if (!contagemPorCliente.containsKey(ag.Cliente__c)) {
        contagemPorCliente.put(ag.Cliente__c, 0);
      }
      contagemPorCliente.put(
        ag.Cliente__c,
        contagemPorCliente.get(ag.Cliente__c) + 1
      );
    }

    // LOOP FINAL: Aplica Nome Customizado e Verifica Limite
    for (Agendamento__c a : Trigger.new) {
      // 1. Lógica do Nome Bonito (Ex: "João Silva - 10/02 14:00")
      if (mapContatos.containsKey(a.Cliente__c)) {
        String nomeCliente = mapContatos.get(a.Cliente__c).Name;
        String dataFormatada = a.Data_Hora__c.format('dd/MM HH:mm');

        // Sobrescreve o campo Name padrão!
        a.Name = nomeCliente + ' - ' + dataFormatada;
      }

      // 2. Lógica do Cliente Fominha
      if (contagemPorCliente.containsKey(a.Cliente__c)) {
        if (contagemPorCliente.get(a.Cliente__c) >= 2) {
          a.addError('Você já tem 2 agendamentos futuros! Limite atingido.');
        }
      }
    }
  }

  // --- LÓGICA 2: DUPLICIDADE DE HORÁRIO ---
  if (!datasParaVerificar.isEmpty()) {
    List<Agendamento__c> conflitos = [
      SELECT Data_Hora__c
      FROM Agendamento__c
      WHERE Data_Hora__c IN :datasParaVerificar AND Id NOT IN :Trigger.new
    ];
    Set<Datetime> datasOcupadas = new Set<Datetime>();
    for (Agendamento__c ag : conflitos)
      datasOcupadas.add(ag.Data_Hora__c);

    for (Agendamento__c a : Trigger.new) {
      if (datasOcupadas.contains(a.Data_Hora__c)) {
        a.addError('Horário indisponível.');
      }
    }
  }
}
