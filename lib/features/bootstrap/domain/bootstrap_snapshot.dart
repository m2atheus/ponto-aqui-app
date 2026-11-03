import '../../../core/clock/clock_sample.dart';
import '../data/mobile_sync_dto.dart';

class BootstrapSnapshot {
  const BootstrapSnapshot(this.data, this.clock);
  final MobileSyncDto data;
  final ClockSample clock;

  FuncionarioSyncDto? employeeFor(String userId) {
    if (data.modoOperacao == ModoOperacao.pessoal) {
      return data.funcionario?.usuarioId == userId ? data.funcionario : null;
    }
    final matches = data.funcionarios
        .where((f) => f.funcionario.usuarioId == userId)
        .toList();
    return matches.length == 1 ? matches.single.funcionario : null;
  }

  List<AlocacaoPessoalSyncDto> allocationsFor(String userId) {
    if (employeeFor(userId) == null) return const [];
    if (data.modoOperacao == ModoOperacao.pessoal) return data.alocacoes;
    final employee = data.funcionarios.singleWhere(
      (f) => f.funcionario.usuarioId == userId,
    );
    final sector = data.setor;
    if (sector == null) return const [];
    return List.unmodifiable(
      employee.alocacoes.map(
        (a) => AlocacaoPessoalSyncDto(
          id: a.id,
          dataInicio: a.dataInicio,
          dataFim: a.dataFim,
          setor: sector,
          escala: data.escalas.where((s) => s.id == a.escalaId).firstOrNull,
        ),
      ),
    );
  }

  String? captureRestriction(
    DateTime now, {
    String? userId,
    String role = 'FUNCIONARIO',
  }) {
    if (role != 'FUNCIONARIO') {
      return 'Entre com sua própria conta de funcionário para registrar ponto.';
    }
    final employee = userId == null ? data.funcionario : employeeFor(userId);
    if (employee == null) {
      return 'Seu usuário não possui um funcionário vinculado neste contexto.';
    }
    if (!clock.usable(now)) {
      return 'Atualize a carga: a amostra do relógio está vencida ou o horário do aparelho mudou.';
    }
    if (ClockSample.civilDate(clock.estimate(now), data.fusoHorario) !=
        data.dataReferencia) {
      return 'Atualize a carga para obter os vínculos do dia da empresa.';
    }
    final allocations = userId == null
        ? data.alocacoes
        : allocationsFor(userId);
    if (allocations.isEmpty) {
      return 'Você não possui alocação disponível neste setor.';
    }
    return null;
  }
}
