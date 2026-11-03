# A2 — предложение контракта FormulaAST, Reaction и BalanceResult

Дата: 2026-11-02  
Статус: предложение для интеграции, не утверждённый публичный DTO. Только исследование и спецификация; код запрещён до утверждения OpenSpec baseline владельцем.

## 1. Границы MVP

Основано на решениях владельца, design и отчёте A2:
- Простые формулы, индексы, вложенные круглые группы, явные заряды.
- Фазы (s), (l), (g), (aq) отдельны от формулы.
- Коэффициент реакции отдельный от формулы.
- Парсинг, domain validation и балансировка — отдельные стадии.
- Парсер не балансирует и не исправляет ввод.
- Гидраты, комплексы, полуреакции ОВР, сложные органические структуры и изотопная нотация не входят в грамматику MVP.
- Неоднозначный/неподдерживаемый синтаксис отклоняется целиком, без успешного частичного AST.

## 2. Разделение сущностей и владение полями

| Сущность | Владеет | Не владеет |
|---|---|---|
| FormulaAST | Element counts, nested round groups, net_charge | Phase, coefficient, kinetic orders |
| SpeciesRef | Stable species ref, FormulaAST ref, phase | Дублирующий charge, amount |
| ReactionTerm | SpeciesRef, side, positive stoichiometric coefficient | Kinetic order, k |
| Reaction | Reactants/products, arrow type, conditions, balance status | Rate law parameters |
| BalanceResult | Coefficients, uniqueness/status, method, residuals, diagnostics | Мутация исходного AST |
| ExperimentComponent | SpeciesRef + experiment-specific amount/state | Семантика формулы |

FormulaAST содержит состав и signed integer net_charge. SpeciesRef задаёт фазовый контекст. Одна FormulaAST может использоваться в нескольких фазах. Это соответствует A1 cross-review и устраняет дублирование заряда.

## 3. Предлагаемые логические DTO

Это не окончательная сериализация.

FormulaAST:
- formula_ast_version
- composition: набор ElementKey → positive integer count
- net_charge: signed integer (0 для нейтральной формулы)
- optional source span / normalized source

SpeciesRef:
- species_id
- substance_id
- formula_ast_ref
- phase: s | l | g | aq

ReactionTerm:
- species_ref
- side: reactant | product
- stoichiometric_coefficient: positive integer; при отсутствии во вводе default 1

Reaction:
- reaction_id, schema_version
- reactants[], products[]
- arrow_type: forward | equilibrium
- conditions
- balance_status: not_checked | balanced | unbalanced | ambiguous | invalid

BalanceResult:
- status: unique | ambiguous | no_solution | invalid_input
- coefficients[]
- method_id
- element_residuals[]
- charge_residual
- diagnostics[]

Предложение: входной Reaction/AST immutable; применение BalanceResult создаёт новую revision реакции, а не меняет исходный объект. Требует решения интегратора.

## 4. Предлагаемая грамматика

EBNF-подобная запись для дальнейшего уточнения:

    equation  = side, ws, arrow, ws, side ;
    side      = term, { ws, "+", ws, term } ;
    term      = [ positive_integer ], ws, species ;
    species   = formula, [ charge ], [ phase ] ;
    formula   = unit, { unit } ;
    unit      = element, [ positive_integer ]
              | "(", formula, ")", [ positive_integer ] ;
    charge    = "^", [ positive_integer ], ("+" | "-") ;
    phase     = "(s)" | "(l)" | "(g)" | "(aq)" ;
    arrow     = "->" | "<->" ;
    element   = uppercase, { lowercase } ;

Важное замечание: это пока grammar proposal, не готовая формальная грамматика. Необходимо согласовать:
- поддерживать ли короткую запись H+ / OH- / Ag+ из примеров владельца;
- каноническая однозначная запись многоразрядного заряда: Fe^3+, SO4^2-;
- запись без caret вроде Fe3+ неоднозначна и должна отклоняться;
- единый токен обратимой стрелки;
- phase суффикс располагается после charge.

Рекомендация A2: принимать caret syntax для всех зарядов, включая +1/-1, а короткие формы H+ и OH- оставить только как явно определённые lexer aliases, если владелец подтвердит это. Не угадывать заряд из цифр в Fe3+.

## 5. Lexer/parser rules

1. Индекс — положительное целое после элемента/группы; отсутствие индекса означает 1; ноль запрещён.
2. Коэффициент — целое перед species в позиции ReactionTerm; не входит в FormulaAST.
3. Заряд — явный signed integer; отсутствие суффикса означает 0.
4. Фаза — только s/l/g/aq; парсер не выводит фазу из контекста.
5. Регистр символов элементов значим; неизвестный элемент диагностируется.
6. Скобки должны быть сбалансированы и корректно вложены.
7. Гидратная точка, квадратные группы комплексов, isotope syntax, radical notation, redox electron half-reactions и органические связи вне MVP.
8. Неподдерживаемый синтаксис не должен автоматически превращаться в пользовательское гипотетическое вещество.

## 6. Pipeline

### A. Lex/Parse
Вход: текст. Выход: синтаксический AST или diagnostics. Не балансирует, не исправляет и не выводит кинетические порядки.

### B. Domain validation
Проверяет известные символы элементов, положительность индексов/коэффициентов, корректность charge/phase, непустые стороны, отсутствие конфликтующих аннотаций. Синтаксическая ошибка означает отказ от полного parse result.

### C. Balance
Построить стехиометрическую матрицу по каждому элементу и отдельной строке заряда; найти положительный целочисленный вектор коэффициентов. После решения повторно проверить каждый элемент и суммарный заряд.

- Нет положительного решения → no_solution.
- Единственное решение с точностью до общего множителя → unique; нормализовать до минимальных целых коэффициентов.
- Несколько независимых допустимых решений или недостаточно ограничений → ambiguous; не выбирать произвольно.
- Коэффициенты строго положительны.
- Не обещать универсальную балансировку редокс-полуреакций: они вне MVP.

Точные пределы размера матрицы, коэффициентов и времени выполнения должны быть установлены в техническом design после benchmark.

## 7. Диагностики (локальные предложения A2)

| Код | Условие |
|---|---|
| PARSER_UNEXPECTED_TOKEN | Неожиданный токен |
| PARSER_UNCLOSED_GROUP | Незакрытая скобка |
| PARSER_UNKNOWN_ELEMENT | Неизвестный символ элемента |
| PARSER_AMBIGUOUS_CHARGE | Неоднозначная запись заряда |
| PARSER_UNSUPPORTED_SYNTAX | Неподдерживаемая конструкция |
| PARSER_INVALID_INDEX | Нулевой/отрицательный индекс |
| PARSER_INVALID_COEFFICIENT | Нулевой/отрицательный/нецелый коэффициент |
| PARSER_INVALID_PHASE | Неизвестная фаза |
| REACTION_EMPTY_SIDE | Пустая сторона реакции |
| BALANCE_NO_POSITIVE_SOLUTION | Нет положительного решения |
| BALANCE_AMBIGUOUS | Неоднозначное решение |
| BALANCE_ELEMENT_RESIDUAL | Ненулевой остаток элемента |
| BALANCE_CHARGE_RESIDUAL | Ненулевой остаток заряда |

Это не отдельный error envelope: коды должны быть вложены в общий DomainError, который утвердит интегратор.

## 8. Acceptance tests

Parse positive:
- H2 + O2 -> H2O: parse success; коэффициенты default 1; баланс ещё не запускался.
- 2H2(g) + O2(g) -> 2H2O(l): coefficient, phase и formula разделены.
- Ca(OH)2 + HCl -> CaCl2 + H2O: корректный состав вложенной группы.
- SO4^2-(aq), Fe^3+(aq): signed charge и phase разделены.
- Ag^+(aq) + Cl^-(aq) -> AgCl(s): заряд и фаза не смешиваются.

Parse negative:
- неизвестный элемент; незакрытая скобка; неоднозначное Fe3+; индекс 0; коэффициент 0/negative; неизвестная фаза; гидратная точка; квадратная комплексная группа; redox half-reaction; неподдерживаемая органическая структура.

Balance:
- H2 + O2 -> H2O => 2,1,2.
- Ag^+(aq) + Cl^-(aq) -> AgCl(s) => 1,1,1; atom and charge balance.
- Ca(OH)2 + HCl -> CaCl2 + H2O => 1,2,1,2.
- Atom-balanced but charge-unbalanced input fails charge validation.
- No positive solution → no_solution.
- Multiple independent valid solutions → ambiguous, never arbitrary selection.
- Parse round-trip preserves formula, charge and phase; parse never balances.

Cross-contract:
- FormulaAST identity excludes phase.
- SpeciesRef phase variants may point to same FormulaAST.
- FormulaAST is the single source of net_charge truth.
- ReactionTerm coefficient does not alter FormulaAST.
- Kinetic order is not present in parser AST.
- UI coordinates/display units do not affect reaction identity.

## 9. Открытые решения интегратора

1. Stable Species ID vs deterministic composite key (INT-02).
2. Short charge notation H+ / OH- vs caret-only; owner examples currently use short notation.
3. Exact equilibrium arrow token and aliases.
4. Duplicate terms (H2 + H2) — preserve or canonicalize by aggregation.
5. Same species on both sides — allow or reject.
6. Element/isotope support and canonical ordering.
7. Whether formula without phase is parseable in editor/catalog but blocked by phase-dependent models.
8. Definition of uniqueness for integer null-space solutions and coefficient limits.
9. Immutable BalanceResult vs creating a new Reaction revision.
10. Mapping local diagnostics into shared DomainError and schema versioning.

## 10. Межагентные границы

- A1: FormulaAST owns composition/charge; SpeciesRef phase separate; SubstanceRecord not conflated with species.
- A3: equilibrium references Reaction/SpeciesRef; standard state/activity basis is not inferred from formula text.
- A4: stoichiometric coefficients and kinetic orders are independent; kinetic model references reaction ID/revision.
- A5: parse and balance are separate user actions; diagnostics shown without silent repair.
- Integrator: approve IDs, grammar, arrows, duplicate policy, immutability and error namespace.

## 11. Рекомендация A2

Сейчас фиксировать ownership model и pipeline; не выбирать implementation library/algorithm prematurely. До закрытия grammar questions, numeric fixtures и явного approval OpenSpec baseline код не писать.
