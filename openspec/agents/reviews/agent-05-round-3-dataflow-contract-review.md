# A5 — Round-3 data-flow contract review

Дата: 2026-11-02  
Статус: **review / integration proposal only**. Не является утверждённым DTO, API или разрешением на реализацию.

## 1. Область проверки

Проверен сквозной путь данных по текущим материалам ветки `openspec/review-round-1`:

1. `FormulaAST → SpeciesRef → ReactionTerm`;
2. `Reaction → KineticModel → SolverResult`;
3. `SolverResult → GraphSeries → Timeline/Replay`.

Сверены A2 contract proposal, A3 equilibrium contract proposal, A4 round-1 review, integrator decision register, OpenSpec design и три A5 review documents. Цель — определить, может ли Godot Presentation/Application adapter безопасно потреблять контракты без догадок и повторной химической/численной логики.

## 2. Краткий вывод

**Сквозной adapter contract пока не готов.** На уровне смысловых границ есть хорошее согласование, но нет замороженных идентификаторов, единиц, общих диагностик, solver result/time-series schema и replay guarantees.

A5 может продолжать UX и acceptance specification. Нельзя начинать сериализацию/адаптеры/графики на предположениях из review proposals.

## 3. Поток A: FormulaAST → SpeciesRef → ReactionTerm

### Согласовано

- FormulaAST владеет элементным составом и signed integer `net_charge`.
- FormulaAST не владеет phase, reaction coefficient или kinetic order.
- SpeciesRef ссылается на FormulaAST и задаёт фазовый контекст.
- ReactionTerm задаёт сторону реакции и положительный стехиометрический коэффициент.
- ExperimentComponent отделяет экспериментальное количество/состояние от каталожной идентичности.
- Parser, domain validation и balancing — разные стадии; UI не исправляет ввод молча.

### Открытые блокеры

1. **SpeciesRef identity / lifecycle (INT-02).** В A2 есть `species_id`, `substance_id`, `formula_ast_ref`, `phase`, но нет решения о namespace, неизменяемости semantic identity, alias/duplicate policy, правилах revision и поведении при изменении FormulaAST. UI не может надёжно сохранять ссылку только по display formula.
2. **Charge duplication (INT-03).** A2 однозначен, но в A1 §2.2 остаётся `SubstanceRecord.formal_charge` MUST. Требуется исправить исходную таблицу A1 или явно обозначить поле как вычисляемое, неперсистентное отображение `FormulaAST.net_charge`.
3. **Source-span contract.** A2 допускает optional source span / normalized source, но не фиксирует единицы offsets (UTF-8 bytes, Unicode scalar values, UTF-16 code units), end-exclusive/inclusive semantics, normalization mapping и сохранение исходного текста. Для русскоязычного редактора и подсветки diagnostics это существенно.
4. **Phase optionality / syntax policy.** A2 оставляет optionality phase и неоднозначности синтаксиса открытыми. До решения UI не должен сам добавлять фазу по умолчанию или превращать отсутствие phase в `(aq)`.
5. **Reaction identity/revision.** Для устойчивых ссылок из KineticModel/EquilibriumProblem нужен явный Reaction ID + revision и политика изменения/копирования реакции. A3 уже ссылается на Reaction ID + revision, но parser proposal должен согласовать тот же контракт.

### A5 adapter rule

UI сохраняет raw input и показывает AST/diagnostics как отдельные результаты. Он не строит FormulaAST, не выводит phase из каталожной карточки и не синтезирует стабильные IDs.

## 4. Поток B: Reaction → KineticModel → SolverResult

### Согласовано

- Стехиометрические коэффициенты не равны кинетическим порядкам.
- K не задаёт временной масштаб.
- Размерность k зависит от rate law и rate basis.
- Нельзя универсально задавать `kf/kr = K`.
- Equilibrium solve, kinetic ODE и thermal model — разные задачи.
- MVP изотермический; T(t) не должна отображаться как динамический нагрев.

### Открытые блокеры

1. **Нет A4 normative contract proposal.** Текущий A4 материал — профильное ревью с рекомендациями, а не схема `KineticModel/KineticParameterSet/SolverResult`. INT-10/11/17/18/19/21/22 остаются открытыми.
2. **Rate law representation.** Нужны однозначные species/reaction references, reaction order representation, rate basis, forward/reverse direction, parameter dimensions, reference T, Arrhenius applicability и provenance/uncertainty. UI не должен выводить порядки из коэффициентов.
3. **Solver termination vs result validity.** Нужны раздельные termination reason, numerical status, estimated error, invariant residuals, model applicability и completeness. `converged` само по себе не означает научную применимость.
4. **Sample validity / non-finite values.** Не определено, как сериализуются invalid, missing, rejected, event-boundary и non-finite samples. Нельзя отображать их как ноль или соединять линией через gap.
5. **Event ordering.** Нужен канонический порядок same-time events, правило применения на границе solver step и связь event sequence с snapshot. UI не сортирует события самостоятельно.
6. **Temperature series.** Для MVP источник T — canonical experiment conditions; температурный ряд постоянен и помечен «Изотермическая модель». Нельзя генерировать ряд из UI animation или визуальных состояний.

### A5 adapter rule

Kinetic panel отображает rate-law/parameter fields и diagnostics, возвращённые domain/application layer. Графики получают готовые typed quantities; A5 не пересчитывает rate units, не исправляет отрицательные концентрации и не запускает solver.

## 5. Поток C: SolverResult → GraphSeries → Timeline/Replay

### Открытые блокеры

1. **GraphSeries отсутствует как согласованный публичный контракт.** Нужны stable series ID, semantic key, quantity kind, unit ID/dimension, time basis/unit, source result/revision, sample validity, gap semantics и provenance.
2. **Time model.** Не определены точность timestamp, monotonicity, duplicate timestamps, event/sample ordering, clock origin и правила связи solver steps с отображаемыми точками.
3. **Interpolation/decimation.** До решения A4 UI не интерполирует gaps и не меняет смысл данных при downsampling. Любая визуальная агрегация должна сохранять min/max/extrema и отмечать derived display points, если она будет разрешена.
4. **Replay guarantee.** Требуется объявить bitwise, deterministic-on-same-platform либо tolerance-bounded reproducibility. Сохраняются exact model/data versions, solver settings/tolerances, initial state, ordered events и seed при наличии. UI layout, zoom, display units, selection и visual coordinates исключены из simulation hash.
5. **History semantics.** Rewind к snapshot, replay из начала и простое перемещение timeline cursor — разные операции. Нужны доступность/границы snapshots, поведение после изменения эксперимента и индикация stale history.
6. **Graph synchronization.** Общий cursor должен ссылаться на canonical model time, а не на индекс массива точек; series с разными sampling schedules должны синхронизироваться без подмены отсутствующих значений.

### A5 adapter rule

Graph view потребляет immutable result/series snapshots и canonical timeline events. Он не выполняет chemistry, solver, unit conversion beyond shared UnitRegistry, interpolation through invalid gaps или independent event ordering.

## 6. A3 equilibrium contract — дополнительная граница

A3 proposal хорошо разделяет thermodynamic/activity pH и ideal concentration approximation, а также требует basis/standard-state compatibility, activity model и applicability checks. Но enum values, StandardStateRef, UnitId и общая ErrorEnvelope ещё не frozen.

UI должен показывать label/method, basis, model/version, validity и warnings, которые пришли из результата. Он не должен вычислять `-log10([H+])` и выдавать его за thermodynamic pH, пересчитывать Q/K или скрывать out-of-domain status.

## 7. Что требуется закрыть владельцам

| ID / область | Требуемое решение | Владелец |
|---|---|---|
| INT-02/03 | Species identity/alias/revision; убрать дублирующий formal_charge из SubstanceRecord | Интегратор + A1/A2 |
| A2 spans | Offset unit, range convention, normalization map | A2 |
| A2 phase | Required/optional policy и default prohibition | Интегратор + A2 |
| Reaction identity | Stable ID/revision lifecycle | Интегратор + A2/A3/A4 |
| INT-04–09 | Basis, standard states, activity model, pH, precipitation, K(T) | A3 + A1 |
| INT-10/11/12 | Normative kinetic model/rate law/reversible linkage | A4 + A3 + A2 |
| INT-13–16 | Unit Registry, missing semantics, ErrorEnvelope, schema policy | Интегратор + A1–A5 |
| INT-17/18 | Event order, canonical simulation snapshot/hash, replay guarantee | A4 + интегратор |
| INT-19/20/22 | SolverResult, sample validity, ReliabilityVector, tolerance policy | A4 + A5 + A3 |
| GraphSeries | Typed time-series contract and display sampling policy | A4 + A5 |

## 8. A5 readiness decision

- **Можно продолжать:** IA, interaction design, blocked/error UX, graph layout specification, hazard/provenance presentation rules, offline UX, accessibility and visual asset review.
- **Нельзя начинать:** DTO serialization, typed graph adapter, timeline/replay adapter, save migration code, Godot scenes/scripts, solver visualization bound to assumed fields.
- **Не менялось:** чужие DTO, OpenSpec baseline, main, runtime implementation.

## 9. Approval boundary

Этот документ фиксирует результаты ревью и вопросы интеграции. Он не утверждает решения INT, не заменяет A1–A4 contracts и не разрешает implementation. Следующий переход — после явного ответа владельца/интегратора и публикации согласованных versioned contracts.
