import '../../../core/clock/clock_sample.dart';
import '../data/mobile_sync_dto.dart';

class BootstrapSnapshot {
  const BootstrapSnapshot(this.data, this.clock);
  final MobileSyncDto data;
  final ClockSample clock;

  String? captureRestriction(DateTime now) {
    if (data.modoOperacao != ModoOperacao.pessoal) {
      return 'O envio coletivo depende de integração no servidor.';
    }
    if (data.funcionario == null) {
      return 'Solicite a vinculação do seu cadastro de funcionário.';
    }
    if (!clock.usable(now)) {
      return 'Atualize a carga: a amostra do relógio está vencida ou o horário do aparelho mudou.';
    }
    if (ClockSample.civilDate(clock.estimate(now), data.fusoHorario) !=
        data.dataReferencia) {
      return 'Atualize a carga para obter os vínculos do dia da empresa.';
    }
    if (data.alocacoes.isEmpty) return data.mensagemStatus;
    return null;
  }
}
