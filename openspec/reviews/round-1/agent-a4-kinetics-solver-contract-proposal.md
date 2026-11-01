# A4 — предложение контракта кинетики и численного solver

Дата: 2026-11-02  
Статус: проект для интеграции; не утверждённый публичный DTO, не выбор библиотеки и не разрешение на реализацию.  
Основание: A4 review round 1, A1/A2/A3 предложения, integrator decision register и утверждённые владельцем ограничения MVP.

## 1. Границы трёх вычислительных задач

Необходимо строго разделить:
1. Equilibrium solve — определяет состояние равновесия из термодинамических констант и балансов. Не задаёт время достижения.
2. Kinetic simulation — интегрирует систему ODE по заданным законам скорости и параметрам.
3. Energy/thermal model — рассчитывает изменение температуры через энергетические балансы. В MVP отсутствует.

MVP изотермический: T постоянна на протяжении расчёта. График T(t) должен быть постоянным и явно подписанным «изотермический режим». Не выводить T(t) из одной кинетики.

Конечное смешивание и spatial/compartment модели не входят в MVP. Визуальная анимация не должна имитировать физическое смешивание.

## 2. Модель состояния и кинетическое уравнение

Для закрытой однородной системы в согласованном basis:
dc/dt = N · r(c,T), где N — стехиометрическая матрица, r — вектор скоростей реакций. Конкретная форма состояния (amounts или concentrations) должна быть согласована с реакторным объёмом и единицами. Нельзя смешивать rate per volume и amount/time.

Для открытой системы концептуально:
dn/dt = N · V · r(c,T) + F_in(t) − F_out(t).

Это запись для согласованного concentration-rate basis; потоковые члены должны иметь размерность amount/time. Для переменного объёма/плотности нужна отдельная формулировка; выражение не универсально.

MVP поддерживает closed batch, constant inflow/outflow, piecewise-constant flow schedules и discrete add/remove events. Не поддерживает произвольные непрерывные функции потока, пространственные градиенты и конечную скорость смешивания.

## 3. RateLaw contract

RateLaw задаётся отдельно от Reaction stoichiometry. Коэффициенты реакции не являются автоматическими kinetic orders.

Предлагаемые поля:
- rate_law_id, schema_version, reaction_ref + revision;
- direction: forward / reverse / net;
- functional_form_id из ограниченного реестра;
- species refs, к которым относится закон;
- kinetic_orders[] с явными значениями и ссылками на species;
- rate_basis: concentration_per_time / amount_per_time / иной утверждённый basis;
- concentration_scale and unit refs;
- rate_constant_ref;
- validity domain and assumptions.

Для простого степенного закона: r = k · product(a_i ^ alpha_i), либо концентрационная форма с явно указанным concentration basis. Активности и концентрации нельзя взаимозаменять без модели и согласованного определения k.

Если скорость имеет размерность concentration/time и суммарный порядок n, размерность k равна [C]^(1−n)[t]^-1. Для скорости amount/time размерность иная. Следовательно, s^-1 применимо только к конкретному закону первого порядка и rate basis, но не универсально.

Нулевые, дробные и отрицательные порядки не запрещать математически глобально, но MVP принимает только явно поддержанные формы и домены. Отрицательные степени при нулевой концентрации требуют validation/blocking, а не бесконечного значения.

## 4. KineticParameterSet и Arrhenius

KineticParameterSet должен ссылаться на RateLaw и содержать:
- parameter_set_id, schema_version;
- k_ref и его unit/dimension;
- reference_temperature T_ref;
- optional activation_energy Ea с unit;
- gas_constant convention/unit, согласованные с Ea;
- valid_temperature_range;
- reaction direction (forward/reverse);
- uncertainty and significant digits;
- provenance/source/version;
- applicability conditions (medium, phase, solvent, pressure, composition);
- parameter status: present / not_reported / unknown / not_applicable.

Arrhenius relation:
k(T) = k_ref · exp[-Ea/R · (1/T − 1/T_ref)].

Формула допустима только при наличии применимого Ea, T_ref, согласованных единиц Ea и R и заявленного диапазона температур. Если Ea отсутствует, температурную зависимость нельзя выдумывать. В изотермическом MVP T берётся из условий эксперимента; температурный пересчёт k разрешён только при валидированном параметре и в пределах диапазона.

Не смешивать Arrhenius k(T) с термодинамической K(T): это разные величины и модели.

## 5. Обратимые реакции и согласование с равновесием

Для обратимой реакции явно задаются forward/reverse rate laws либо единый net rate law, если его форма валидирована. Нельзя автоматически предполагать kf/kr = K.

Связь кинетики с equilibrium constant зависит от форм forward/reverse laws, kinetic orders, concentration/activity basis, standard states, размерностей k и convention для reaction quotient.

Контракт предусматривает cross-validation: при условиях, где kinetic model применима, её стационарное состояние должно быть совместимо с соответствующим термодинамическим равновесием в рамках заявленных допусков. Если данных недостаточно или формы несовместимы, reversible simulation блокируется либо явно помечается как empirical kinetic model без гарантии термодинамической согласованности.

## 6. SimulationProblem / SimulationState

SimulationProblem (предварительная логическая структура):
- problem_id, schema_version;
- reaction_refs[] (ID + revision);
- kinetic_model_refs[] / RateLaw refs;
- parameter_set_refs[];
- initial_state[]: SpeciesRef + amount/concentration + unit/basis;
- reactor_mode: closed_batch / open_well_mixed;
- volume and volume policy;
- temperature (constant) and pressure/medium where applicable;
- flow_schedules[];
- discrete_events[];
- simulation_time_span and requested output sampling;
- solver_policy_ref (tolerances, step bounds, event policy);
- model/data versions and provenance.

SimulationState:
- timestamp/time unit;
- species amounts/concentrations with explicit basis;
- reactor volume if defined;
- cumulative inflow/outflow and event ledger;
- current constant T;
- invariant/reference totals needed for diagnostics.

Chemical state не содержит UI voxel coordinates, camera, panel layout или display-only units.

## 7. Open systems, flow schedules and discrete events

FlowSchedule для MVP:
- stream_id, species composition;
- flow basis (amount/time или volume/time with defined composition/concentration);
- constant value and unit;
- start_time/end_time;
- boundary convention (half-open interval must be standardized);
- provenance/user-defined status.

DiscreteEvent:
- event_id, timestamp;
- kind: add / remove;
- species refs and amounts;
- event order/sequence;
- source (user action or scheduled event).

Событие применяется точно на временной границе. При совпадении с границей интеграционного шага solver завершает шаг на этой границе, применяет события в детерминированном порядке и продолжает с нового состояния. Событие нельзя терять внутри шага или размазывать по соседним интервалам.

Одинаковые timestamp требуют единой ordering policy: окончательный порядок add/remove/flow-boundary/snapshot остаётся INT-17. Повторное применение события при rewind/replay запрещено.

## 8. Solver policy — классы, не выбор реализации

Не выбирать конкретную библиотеку/язык до benchmark.

A4 review указывает ориентир:
- non-stiff: explicit adaptive Runge–Kutta (например RK45/DOP853);
- stiff: implicit Radau/BDF или LSODA с обнаружением жёсткости.

Это классы для benchmark, а не утверждение, что один метод достаточен для всех задач. Выбор и stiffness detection должны быть обоснованы benchmark на целевых сценариях.

SolverPolicy явно задаёт:
- absolute/relative tolerances с единицами/масштабированием;
- min/max step and initial step policy;
- maximum work/step budget;
- event handling and output sampling policy;
- positivity policy;
- termination conditions;
- deterministic/replay settings.

Один epsilon для концентраций, балансов и error estimate недопустим. Tolerance policy остаётся INT-22.

## 9. Положительность и сохранение инвариантов

Безусловный clipping отрицательных концентраций запрещён: он способен нарушить элементные балансы и создать/уничтожить вещество.

Стратегии для исследования:
- reject/reduce step при выходе из допустимой области;
- positivity-aware/constraint-aware integration;
- correction только если она математически обоснована, ограничена и после неё проверены balances и charge invariants.

Если solver не может обеспечить positivity и инварианты одновременно в заданных допусках, он должен завершиться диагностируемой ошибкой, а не вернуть визуально удобный результат.

Для закрытой системы проверяется сохранение каждого элемента и net charge с учётом стехиометрии. Для открытой — баланс с интегрированными потоками и дискретными событиями. Не применять charge conservation как безусловное ограничение к произвольному открытию/удалению заряженных компонентов без проверки физического смысла модели.

## 10. SolverResult и диагностики

Предлагаемые статусы:
- completed;
- completed_with_warnings;
- blocked (missing data / unsupported model);
- out_of_domain;
- step_limit_reached;
- numerical_failure;
- invariant_violation;
- cancelled.

SolverResult содержит:
- final_state and time_series samples;
- requested/actual time span;
- accepted/rejected step counts;
- solver class/name/version and settings;
- termination reason;
- local error estimates if available;
- invariant residuals (element, charge, total amount/flow accounting);
- positivity diagnostics/minimum encountered state;
- event application log;
- warnings and model/data refs.

SolverDiagnostics — структурированные сведения о failure, convergence/step rejection, stiffness indicator if available, residuals and offending time/species/reaction. Не смешивать numerical status с data quality/model validity; это отдельные оси ReliabilityVector A5.

## 11. Rewind, replay and deterministic identity

Для воспроизводимости сохранять:
- canonical initial chemical state;
- Reaction/RateLaw/KineticParameterSet revisions;
- data/model versions and provenance refs;
- constant T and reactor conditions;
- ordered discrete events and flow schedules;
- solver class/version, settings, tolerances, step/event policy;
- output sampling policy;
- random seed только если стохастика когда-либо появится (она не входит в MVP).

Replay identity/hash не включает UI layout, voxel coordinates, camera, display unit preferences. Он включает все входы, способные повлиять на расчёт. Детерминизм проверяется в declared tolerances; bitwise identity между разными платформами/solver versions не обещается без отдельного требования.

## 12. Temperature-time graph

В MVP температура постоянна на всём интервале. График T(t) показывает горизонтальную линию при заданной температуре и label «изотермический режим», не имитирует нагрев/охлаждение вследствие реакции.

Неизотермический режим — отдельный будущий модуль. Для него нужны как минимум ΔH реакции, Cp компонентов/сосуда, теплопотери/теплообмен и граничные условия. До появления этих данных T(t) не рассчитывать.

## 13. Кандидаты subsystem error codes

KINETICS_MISSING_RATE_LAW; KINETICS_MISSING_PARAMETER; KINETICS_RATE_UNIT_MISMATCH; KINETICS_ORDER_UNSUPPORTED; KINETICS_NEGATIVE_STATE_DOMAIN; KINETICS_ARRHENIUS_OUT_OF_RANGE; KINETICS_REVERSIBLE_THERMO_MISMATCH; SIMULATION_FLOW_BASIS_MISMATCH; SIMULATION_EVENT_ORDER_CONFLICT; SIMULATION_EVENT_APPLICATION_FAILURE; SOLVER_STEP_LIMIT_REACHED; SOLVER_NUMERICAL_FAILURE; SOLVER_INVARIANT_VIOLATION; SOLVER_POSITIVITY_FAILURE; SIMULATION_REPLAY_INPUT_MISMATCH.

Коды не утверждены; общий DomainError envelope, severity, context и recoverability задаёт интегратор (INT-15).

## 14. Benchmark matrix and acceptance

A4 review round 1 требует следующие benchmark-классы:
1. Analytical first-order decay.
2. Reversible first-order reaction.
3. Arrhenius ratio at two temperatures.
4. Conservation in closed systems.
5. Open-system constant inflow/outflow.
6. Event insertion at exact timestamp.
7. Stiff benchmark versus non-stiff benchmark.
8. Deterministic replay within declared tolerances.
9. Failure cases: missing k/Ea/K, negative concentrations, solver divergence.

Каждый executable numeric fixture обязан содержать source/derivation, conditions, units, reaction/species, initial state, rate law, parameter provenance, uncertainty, independently derived expected result and benchmark-specific tolerances. В текущем A4 review нет численных эталонных значений; не добавлять их из догадки.

Acceptance invariants:
- closed-system element/charge balances remain within declared tolerances;
- open-system totals match reaction + inflow/outflow + discrete event ledger;
- event timestamps are applied exactly once;
- concentrations remain in permitted domain or solver fails explicitly;
- reversible kinetic equilibrium is cross-checked against compatible thermodynamic model where claimed;
- replay reproduces state trajectory within declared tolerances;
- temperature graph remains constant for isothermal runs.

## 15. Межагентные границы и вопросы интегратора

- A1: unit registry, kinetic parameter provenance, uncertainty and validity.
- A2: Reaction/ReactionTerm/SpeciesRef identity and stoichiometry; kinetic orders remain separate.
- A3: thermodynamic K, standard states, activity basis and reversible equilibrium consistency.
- A4: rate laws, kinetic parameter sets, ODE formulation, solver diagnostics, events and replay requirements.
- A5: experiment document, controls, graph semantics, statuses, result reliability and persistence.

Открытые решения: INT-10 final KineticParameterSet/RateLaw schema and unit dimensions; INT-11 reversible kinetic/thermodynamic consistency; INT-12 reaction revision references and stoichiometry/kinetic-order separation; INT-13 canonical Unit Registry; INT-17 event ordering for equal timestamps; INT-18 replay canonicalization/hash; INT-19/20 result diagnostics and ReliabilityVector boundary; INT-21 positivity strategy; INT-22 benchmark-specific tolerances; INT-25 persistence boundary; INT-26 numeric fixture provenance.

## 16. Рекомендация A4

Сначала согласовать dimensionally complete RateLaw/KineticParameterSet и event/replay semantics; затем выбрать solver class по benchmark. Не выбирать библиотеку заранее, не добавлять численные k/Ea, не обещать универсальную stiffness handling и не реализовывать finite mixing/thermal model. Код и реализация заблокированы до явного утверждения OpenSpec baseline владельцем.
