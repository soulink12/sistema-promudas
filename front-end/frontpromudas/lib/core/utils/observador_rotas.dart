import 'package:flutter/material.dart';

/// Observador de rotas global, registrado no `MaterialApp`.
/// Permite que telas implementem [RouteAware] para reagir quando voltam ao topo
/// da pilha (ex.: o PDV recarrega os produtos ao fechar Configurações).
final RouteObserver<ModalRoute<void>> observadorRotas =
    RouteObserver<ModalRoute<void>>();
