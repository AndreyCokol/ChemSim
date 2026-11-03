# ChemSim — реестр межагентных решений интегратора

Дата: 2026-11-02  
Ветка: `openspec/review-round-1`  
Статус: рабочий реестр для обсуждения; **не утверждённый API и не разрешение на реализацию**.

Документ сводит вопросы, которые нельзя окончательно решить внутри одного профиля A1–A5. Основание — текущие OpenSpec design/specs, отчёты A1–A5 и уже записанные решения владельца. Профильные отчёты — desk reviews в ролях агентов, а не независимые запущенные процессы.

## 1. Принципы, которые не открываем повторно

1. MVP работает офлайн, на Windows 10/11 x64, в ограниченных моделях водных разбавленных растворов и идеальных газов.
2. Парсинг и балансировка — разные операции; формулы MVP: простые формулы, круглые скобки, явные заряды, фазы и отдельные коэффициенты. Гидраты, комплексы, полуреакции ОВР и сложные органические структуры отложены.
3. Водные benchmark-сценарии — пять согласованных реакций; газовые — две согласованные реакции. Это набор сценариев, не численные fixtures.
4. MVP изотермический. Неизотермическая модель не входит в scope.
5. K определяет равновесие, но не временной масштаб. Кинетика требует rate law и параметров.
6. Мгновенное идеальное смешивание разрешено; конечное смешивание отложено. Потоки — постоянные и кусочно-постоянные.
7. Координаты рабочего поля — только UI layout и не влияют на химическое состояние.
8. Недостающие данные блокируют только зависимый расчёт; неполные пользовательские записи можно сохранять.
9. Неопределённые данные и лицензии нельзя молча подменять предположениями.
10. До явного утверждения владельцем OpenSpec baseline код не писать и реализацию не начинать.

## 2. Решения, необходимые до фиксации публичных DTO

| ID | Приоритет | Вопрос / конфликт | Предлагаемое решение | Владелец решения | Блокирует |
|---|---|---|---|---|---|
| INT-01 | P0 | Граница Substance / Species / ExperimentComponent | Развести каталоговую запись, химическую частицу в контексте реакции и компонент эксперимента. SubstanceRecord не содержит quantity/concentration/layout; FormulaAST владеет составом и net charge; SpeciesRef задаёт фазу; ExperimentComponent содержит amount/state. | Интегратор + A1/A2 | Все публичные химические DTO |
| INT-02 | P0 | Идентификатор SpeciesRef | Выбрать стабильный Species ID либо детерминированный составной ключ. Рекомендация: стабильный ID с immutable semantic identity (FormulaAST ref/version + phase context), чтобы документы/эксперименты могли ссылаться на него без зависимости от display string. Утвердить правила alias/duplicate. | Интегратор + A1/A2 | ReactionTerm, catalog refs, save/replay |
| INT-03 | P0 | FormulaAST и charge ownership | FormulaAST хранит элементный/изотопный состав и signed integer net_charge; фаза отдельно. Не дублировать charge как независимое поле SpeciesRef без формально заданной причины. | A2; подтверждает интегратор | Parser AST, species identity |
| INT-04 | P0 | Equilibrium basis enum | A3 должен определить допустимые basis (activity, pressure/partial pressure, concentration, molality и др.), стандартные состояния, dimension convention, преобразования и несовместимость. Не использовать одно поле basis как произвольную строку. | A3 + A1 | ThermoConstantRecord, equilibrium API |
| INT-05 | P0 | Газовая термодинамика в идеальном MVP | Для MVP использовать явно обозначенную идеальногазовую formulation через partial pressures, не обещая fugacity/non-ideal correction. Уточнить, как tabulated K относится к выбранному standard pressure и как выражается Q/K. | A3 | Газовые equilibrium fixtures |
| INT-06 | P0 | Водная activity model | Для каждого aqueous benchmark выбрать конкретный вариант: explicitly ideal dilute (gamma=1) или activity model с параметрами/validity. Не объявлять общий Debye–Hückel scope без проверенного диапазона и набора коэффициентов. | A3 | pH, Ka/Kb, Ksp, precipitation |
| INT-07 | P0 | pH convention | В DTO и UI различать thermodynamic/activity-based pH и explicitly labelled ideal concentration approximation. Не подписывать -log10[H+] как универсальный pH. | A3 + A5 | Aqueous result DTO/UI |
| INT-08 | P0 | Ksp и осаждение | Утвердить набор неизвестных, материальные балансы, электронейтральность, условие насыщения, учёт количества твёрдой фазы и правило появления/исчезновения осадка. Один Qsp-vs-Ksp check не заменяет общий solve. | A3 | AgCl benchmark, equilibrium solver |
| INT-09 | P0 | K(T) | Зафиксировать контракт: K относится к заданным T/standard states; перенос по T разрешён только при валидированных ΔH°/ΔCp° или таблице в пределах применимости. Указать, как uncertainty переносится. | A3 + A1 | ThermoConstantRecord, gas/aqueous fixtures |
| INT-10 | P0 | KineticParameterSet | A4 должен предоставить rate law schema, orders, rate basis, k reference value/T, Ea, units, validity range, provenance/uncertainty и обратное направление. Размерность k вычисляется из rate law/basis; s^-1 не универсальна. | A4 + A1 | Kinetic solver API |
| INT-11 | P0 | Согласованность обратимой кинетики с K | Определить, как rate constants/reverse rate law согласуются с термодинамическим equilibrium constant для конкретной формы закона скорости и standard state. Запретить автоматическое универсальное kf/kr=K. | A4 + A3 | Reversible kinetic simulations |
| INT-12 | P0 | Reaction DTO | ReactionTerm содержит SpeciesRef и положительный stoichiometric coefficient; kinetic orders не выводятся автоматически из коэффициентов. Связь kinetic model с reaction ID/version должна быть явной. | A2 + A4 | Reaction graph, kinetic API |
| INT-13 | P0 | Unit registry и canonical units | Утвердить единый реестр unit ID, размерностей, affine conversion (°C↔K), правила SI/canonical storage и display conversion. Размерность проверяется по property/rate-law key. | Интегратор + A1/A4 | Все DTO, persistence, UI |
| INT-14 | P0 | Missing/null/unknown | Общая семантика absent, null, unknown, not_reported, not_applicable, withheld и zero. Не сводить к null/0. Определить, какие поля обязательны для сохранения, а какие — только для выбранной модели. | Интегратор + A1/A5 | Schema versioning, persistence |
| INT-15 | P0 | Error envelope | Единый error object: machine code, severity, message key, context, missing fields/source refs, recoverability. Владельцы subsystem codes не меняют общий envelope самостоятельно. | Интегратор + A1–A5 | Межслойные API и UX |
| INT-16 | P0 | Schema version policy | Разделить schema_version, record_revision, dataset_version, model_version. Определить unknown-future-version behavior, migration idempotency и backward compatibility. | Интегратор + A1/A5 | Save/load, replay, catalog |
| INT-17 | P0 | Event ordering | Утвердить единый порядок событий при одинаковом timestamp (add/remove/flow boundary/reaction integration/snapshot). События применяются на точной границе шага и должны быть детерминированы. | A4 + A5 | Open systems, replay |
| INT-18 | P0 | Replay identity/hash | Определить canonical simulation input snapshot и hash; исключить UI layout, display units и визуальные координаты. Сохранять точные версии данных/модели, solver settings/tolerances, initial state и ordered events. | A4 + A5 | Deterministic replay, saves |
| INT-19 | P1 | Solver result contract | Разделить solver status, numerical error estimate, invariant residuals, termination reason и time-series sample. Не смешивать numerical convergence с scientific applicability. | A4 + A5 | Result DTO/UI |
| INT-20 | P1 | ReliabilityVector | Согласовать enum/структуры data_quality, model_validity, numerical_status, completeness, warnings. Не вычислять из них «процент точности» или вероятность. | A5 + A1/A3/A4 | Results UX, exports |
| INT-21 | P1 | Positive concentrations | Утвердить positivity policy: step rejection/constraint-aware integration/validated correction; запрещено безусловное clipping, если оно нарушает balances. | A4 | Kinetic solver acceptance |
| INT-22 | P1 | Tolerance policy | Допуски определять по типу величины и benchmark, отдельно для mass/charge conservation, equilibrium residual, solver local/global error, replay comparison. Не назначать единый epsilon всем операциям. | A3 + A4 | Benchmark fixtures |
| INT-23 | P1 | Data license allowlist | Утвердить право распространения каждого набора/поля/версии; отдельно определить коммерческий/некоммерческий режим приложения. Не считать PubChem/ECHA/NIST/CIAAW целиком автоматически разрешёнными. | Владелец + A1 | Built-in catalog bundle |
| INT-24 | P1 | Hazard metadata | Разделить отсутствующие данные, not assessed, known hazard, jurisdiction/classification version. Не трактовать отсутствие данных как отсутствие опасности; не переносить классификацию на смесь автоматически. | A1 + A5 | Encyclopedia and safety UX |
| INT-25 | P1 | Save document boundary | Разделить chemical experiment document, immutable replay metadata, user annotations и UI layout. Утвердить, какие версии сохраняются inline, а какие через content-addressed refs. | A5 + A1/A4 | Save/load and portability |
| INT-26 | P1 | Numerical fixture provenance | Для каждого численного benchmark хранить independent expected value, source/derivation, conditions, basis, uncertainty, units, tolerances, license. Scenario-only cases не выдавать за executable numeric tests. | A1 + A3/A4 | Scientific validation |
| INT-27 | P2 | UI labels/status vocabulary | Утвердить русские пользовательские labels для Ready/Blocked/Running/Paused/Stepping/Completed/Failed/ResultsWithWarnings и причины блокировки. | A5 + владелец | UX polish, not chemistry core |
| INT-28 | P0 | Зарядовая нотация | Согласовать caret-only запись (^+, ^2-, ^3+) либо короткие aliases H+/OH-/Ag+; Fe3+ без caret отклонять как неоднозначное. | Владелец + A2 | Parser grammar and round-trip |
| INT-29 | P0 | Стрелка равновесия | Утвердить единственный canonical token для equilibrium arrow и правила lexer aliases. | Владелец + A2/A3 | Reaction AST and equilibrium input |
| INT-30 | P1 | Дублирующиеся ReactionTerm | Решить, сохранять ли H2 + H2 как два исходных term или агрегировать в один term с коэффициентом; сохранять исходный текст для редактора. | A2 + интегратор | Reaction canonicalization and editing |
| INT-31 | P1 | Species по обе стороны | Определить политику одинакового SpeciesRef на reactant и product side (допуск промежуточных/каталитических случаев либо validation error). | A2 + A4 | Reaction validation and kinetics |
| INT-32 | P1 | Неуказанная фаза | Разрешить parse/catalog записи без phase, но требовать phase для моделей, где она обязательна; parser phase не угадывает. | A1 + A2 + A3 | Catalog, equilibrium and reaction validation |
| INT-33 | P1 | BalanceResult mutability | Утвердить immutable input Reaction + отдельный BalanceResult; применение коэффициентов создаёт новую Reaction revision. | Интегратор + A2/A5 | Editing, persistence, kinetic references |
| INT-34 | P1 | pH result typing | Развести thermodynamic activity-based pH, ideal concentration approximation и unavailable; передавать basis/model/version и исходную H+ activity/concentration. | A3 + A5 + владелец | Scientifically correct pH display |
| INT-35 | P1 | Aqueous ionic-strength domain | Для каждой activity model хранить собственный validity domain; ограничение I < 0.10 mol kg−1 из A3 review относится к конкретной IUPAC форме, не универсально. | A3 + A1 | Activity model applicability gate |
| INT-36 | P1 | Precipitation complementarity | Утвердить совместные mass/charge balances, nonnegative solid amount и saturation/phase appearance conditions; Qsp/Ksp alone недостаточно. | A3 + интегратор | Ksp solver formulation |
| INT-37 | P1 | Equilibrium residual definition | Утвердить residual ln(Q/K) для положительных значений и обработку граничных нулевых активностей без произвольного epsilon. | A3 + A4 | Numerical validation/tolerances |
| INT-38 | P1 | Gas pressure standard state | Зафиксировать standard pressure и dimensionless partial-pressure quotient для Kp fixtures; не смешивать Kp с activity K. | A3 + A1 | Gas equilibrium fixtures |
| INT-39 | P1 | Equilibrium solve domain status | Ввести различимый out_of_domain/blocked status для неподходящей T/P/Ionic strength/model range; запрещена молчаливая экстраполяция. | A3 + A5 | Result validity and UX |
| INT-40 | P0 | RateLaw rate basis and units | RateLaw обязан типизировать amount/time vs concentration/time, concentration scale, kinetic orders и вычисляемую размерность k; s^-1 не универсальна. | A4 + A1 + интегратор | Kinetic API and dimensional validation |
| INT-41 | P0 | Kinetic orders vs stoichiometry | Кинетические порядки задаются явно и не выводятся автоматически из ReactionTerm stoichiometric coefficients. | A4 + A2 | RateLaw validity |
| INT-42 | P1 | Arrhenius applicability | k(T) требует k_ref, T_ref, Ea, согласованных единиц R/Ea и validity interval; не смешивать с thermodynamic K(T). | A4 + A1 | Temperature-dependent kinetic parameters |
| INT-43 | P0 | Reversible kinetic/thermodynamic consistency | Не использовать универсальное kf/kr=K; определить допустимую связь для конкретных rate laws, orders, basis и standard states. | A4 + A3 | Reversible kinetics |
| INT-44 | P1 | Positivity and invariant policy | Запретить unconditional clipping; выбрать step rejection/constraint-aware strategy/correction только с проверкой balances и charge. | A4 | Kinetic solver reliability |
| INT-45 | P1 | Exact-time event application | События применяются ровно на временной границе, один раз и в детерминированном порядке; общий tie-break для одинаковых timestamp остаётся INT-17. | A4 + A5 | Open systems and replay |
| INT-46 | P1 | Solver class selection | Выбор explicit/implicit solver class и stiffness handling должен следовать из benchmark, а не предварительного выбора библиотеки. | A4 | Numerical implementation choice |
| INT-47 | P1 | Isothermal temperature series | В MVP T(t) постоянна и явно маркирована изотермически; energy balance/thermal model вне scope. | Владелец + A4/A5 | Temperature graph semantics |
| INT-48 | P1 | Replay determinism scope | Зафиксировать входы replay/hash и сравнение в declared tolerances; bitwise cross-platform determinism не обещать без отдельного требования. | A4 + A5 | Replay and persistence |

## 3. Набор DTO для последующего согласования

Это список сущностей, не окончательные поля или сериализация:

- A1: SubstanceRecord, SubstanceRef, PropertyRecord, ThermoConstantRecord, SourceRecord/Provenance, HazardRecord, UnitDefinition, DataQuality.
- A2: FormulaAST, SpeciesRef, ReactionTerm, Reaction, BalanceResult, ParserDiagnostic.
- A3: EquilibriumProblem, EquilibriumResult, ActivityModelConfig, EquilibriumConstantRef, Phase/SaturationState.
- A4: KineticModel, RateLaw, KineticParameterSet, SimulationState, FlowSchedule, DiscreteEvent, SolverResult, SolverDiagnostics, ReplayMetadata.
- A5: ExperimentDocument, ExperimentComponent, ResultStatus/ReliabilityVector, UI layout, SaveManifest.

Каждый DTO должен определить: schema_version, identity/reference semantics, canonical units, null/missing semantics, validation errors, provenance/version references и serialization compatibility.

## 4. Минимальный порядок согласования

1. **A1+A2:** FormulaAST/SpeciesRef/SubstanceRecord/ExperimentComponent; убрать дублирование charge/phase.
2. **A3:** basis/standard state/activity model/aqueous & gas equilibrium problem-result contracts.
3. **A4:** RateLaw/KineticParameterSet/SimulationState/events/solver result.
4. **A1+A3+A4:** shared units, constants, uncertainty, applicability and provenance.
5. **A5+интегратор:** ExperimentDocument, ReliabilityVector, error envelope, persistence/replay boundaries.
6. **Владелец:** подтверждение baseline и только после него разрешение реализации.

## 5. Текущие блокирующие условия

- Финальные DTO A2/A3/A4/A5 не представлены как нормативные схемы.
- Не утверждены единый Unit Registry, Error Envelope и schema version policy.
- Нет численных fixtures с independently derived expected values и допусками.
- Нет property-level allowlist встроенных данных с подтверждёнными правами на распространение.
- Не определён правовой режим распространения приложения.
- PR #1 остаётся draft/open; mergeability и актуальные checks нужно перепроверить перед любым решением о merge.

## 6. Что сознательно не решено этим документом

- Не выбирается язык/библиотека реализации solver.
- Не утверждается конкретная модель активности или её диапазон.
- Не добавляются численные K/Ka/Kb/Ksp/k/Ea.
- Не утверждаются финальные публичные DTO и API.
- Не разрешается реализация, merge или изменение продуктового scope.
