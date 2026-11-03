# ChemSim MVP — эталонная матрица проверок

Статус: проект benchmark suite. Численные значения и источники должны быть закреплены в test fixtures до реализации соответствующих моделей.

## Принципы
- Каждый benchmark содержит входные данные, единицы, стандартное состояние, температуру, давление, модель, источник и ожидаемый допуск.
- Проверять не только конечное число, но и инварианты: баланс элементов/заряда, размерности, положительность, равновесный residual, воспроизводимость.
- Нельзя использовать неподтверждённые справочные значения. В тестах аналитические значения выводить из явно заданных входов; справочные значения брать из разрешённого источника и фиксировать его версию.
- Отдельно тестировать отказ при отсутствующих параметрах.

## Матрица
| ID | Подсистема | Тест | Вход/условие | Ожидаемое поведение | Тип проверки |
|---|---|---|---|---|---|
| PAR-01 | A2 | Балансировка воды | H2 + O2 -> H2O | 2H2 + O2 -> 2H2O | exact |
| PAR-02 | A2 | Ионное уравнение | Ag+ + Cl- -> AgCl(s) | Атомы и заряд сбалансированы | invariant |
| PAR-03 | A2 | Различение индекса/коэффициента/заряда | 2H2O, H2O, Fe^3+ | Три разные структуры; без автокоррекции | parser AST |
| PAR-04 | A2 | Неподдерживаемая грамматика | Невалидные скобки/заряд/элемент | Структурированная ошибка; не partial parse | negative |
| DOM-01 | A1 | Единицы и конверсии | mol, g, mol/L, g/L; известны M и V | Размерностно корректная конверсия | dimensional |
| DOM-02 | A1 | Provenance | Два источника одного свойства | Хранить оба значения/источника и различия условий | data integrity |
| DOM-03 | A1 | Лицензия источника | Запись без допустимых условий повторного использования | Не включать в redistributable catalog без проверки | compliance |
| DOM-04 | A1 | Гипотетическое вещество | Пользовательская запись с полным набором заданных свойств | Разрешить расчёт, маркировать результат user-defined | status |
| GAS-01 | A3 | Идеальный газ | PV=nRT, заданные n,V,T | Восстановить P с единичной согласованностью | analytic |
| GAS-02 | A3 | Парциальные давления | Смесь идеальных газов | Сумма pi = P и согласованность ni/ntotal | invariant |
| EQ-01 | A3 | Чистая вода | 25 °C, выбранная Kw и activity model | pH benchmark соответствует выбранной модели/источнику | reference |
| EQ-02 | A3 | Сильная кислота, разбавленный предел | Известная концентрация, ideal dilute assumption | pH приближается к -log10(c/c°); assumption label visible | analytic/approx |
| EQ-03 | A3 | Слабая кислота | Ka + mass balance + electroneutrality | Решение сходится, остатки балансов в допуске | nonlinear |
| EQ-04 | A3 | Осаждение | Заданные Ksp, totals, T, activity basis | До/после соблюдены mass balance и saturation condition | equilibrium |
| EQ-05 | A3 | K basis mismatch | K(activity) подан в pressure/concentration model без преобразования | Расчёт блокируется с диагностикой | negative |
| EQ-06 | A3 | Температурная зависимость K | K(T1), ΔH°/ΔCp° или table отсутствует | Не переносить K на T2; блокировать/предупреждать | negative |
| KIN-01 | A4 | Первый порядок | A -> B, k constant, A0 | A(t)=A0 exp(-kt); B gain matches stoichiometry | analytic |
| KIN-02 | A4 | Обратимая простая кинетика | A ⇌ B, forward/reverse rate params | Equilibrium ratio agrees with specified compatible thermodynamic K | analytic |
| KIN-03 | A4 | Только K без k | Equilibrium K exists, no kinetic params | Equilibrium solve allowed; time simulation blocked | negative |
| KIN-04 | A4 | Аррениус | k(T)=A exp(-Ea/RT) or reference-form | Ratio matches analytic expression; units checked | analytic |
| KIN-05 | A4 | Жёсткая система | Fast + slow reaction timescales | Solver meets tolerances or reports unsupported/failure; no silent instability | numerical |
| SYS-01 | A4 | Закрытая система | No external flows | Element/amount balances conserved within declared tolerance | invariant |
| SYS-02 | A4 | Постоянный вход/выход | Known flow rates | State matches analytical mass-balance solution | analytic |
| SYS-03 | A4 | Дискретное событие | Add/remove at exact t_event | State jump occurs once at exact event boundary | event |
| SYS-04 | A4/A5 | Rewind history vs replay | Same event log/model/data versions | States agree within declared tolerance | reproducibility |
| THM-01 | A4/A5 | Изотермический режим | T fixed | T(t) is constant and labelled isothermal | invariant |
| THM-02 | A4 | Неизотермический режим без Cp/ΔH | Heat model incomplete | Block non-isothermal mode; do not invent temperature curve | negative |
| UX-01 | A5 | Визуальные координаты | Move object on canvas | Simulation state/hash unchanged | invariant |
| UX-02 | A5 | UI units | Change display unit | Canonical SI state unchanged | invariant |
| UX-03 | A5 | Blocked diagnostics | Missing K/k/Ea/P/V | Show exact missing parameters and reasons | UX |
| UX-04 | A5 | Confidence/status | User-defined data or approximations | Display data/model/numerical status separately | UX |
| UX-05 | A5 | Offline | Disconnect network | Catalog, experiments, graphs, save/load still work | integration |

## Допуски
Не назначать единый допуск для всей химии. Установить:
- parser/balance: exact integer invariants;
- dimensional checks: exact unit algebra;
- analytical ODE tests: relative/absolute tolerances fixed per test;
- equilibrium: residual and balance tolerances per model;
- replay: solver-specific tolerance and deterministic settings;
- data: uncertainty and significant digits inherited from source.

Каждый fixture должен хранить ожидаемые результаты с версиями исходных данных и формулой их получения.


## Утверждённые сценарии владельца (2026-11-02)

Ниже зафиксирован состав сценариев. Это **не численные fixtures**: ожидаемые числа, константы и допуски не утверждены, пока не подтверждены источники и условия.

### Водные сценарии
| ID | Сценарий | Что проверяется | Обязательные данные для fixture |
|---|---|---|---|
| AQ-01 | CH3COOH ⇌ H+ + CH3COO− | Слабая кислота, Ka, speciation, pH, mass/charge balance | C0, V, T, Ka basis/standard state, activity assumption, source/version, uncertainty |
| AQ-02 | HCl + NaOH → NaCl + H2O | Сильная кислота/основание, нейтрализация, limiting reagent, pH after reaction | Initial amounts/concentrations, V, T, strong-electrolyte assumptions, source |
| AQ-03 | AgCl(s) ⇌ Ag+ + Cl− | Ksp, saturation, solubility, ionic balance | Ksp basis, T, medium/activity model, initial totals, source/version |
| AQ-04 | NH3 + H2O ⇌ NH4+ + OH− | Weak base, Kb, speciation, pH, balances | C0, V, T, Kb basis/standard state, activity assumption, source |
| AQ-05 | AgNO3 + NaCl → AgCl↓ + NaNO3 | Ion mixing, precipitation extent, limiting reagent, spectator ions | Initial amounts, V, T, Ksp basis, activity assumption, source |

### Газовые сценарии
| ID | Сценарий | Что проверяется | Обязательные данные для fixture |
|---|---|---|---|
| GAS-01 | 2 NO2(g) ⇌ N2O4(g) | Ideal-gas equilibrium, pressure basis, Δn, Kp convention | T, P or V/n, Kp(T), standard pressure, source/version, uncertainty |
| GAS-02 | H2(g) + I2(g) ⇌ 2 HI(g) | Ideal-gas equilibrium, pressure/concentration relation, Δn=0 | T, P or V/n, K basis and standard state, source/version, uncertainty |

### Gate для численного fixture
Fixture может стать исполняемым только после того, как заполнены все обязательные входы, зафиксированы первичный источник/версия/лицензия, единицы, basis и standard state, область применимости, неопределённость, derivation expected result и индивидуальные абсолютный/относительный допуски. При отсутствии любого критического элемента fixture остаётся заблокированным или качественным. Численные значения нельзя назначать по памяти или из непроверенной вторичной страницы.
