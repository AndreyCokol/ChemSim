# A3 — предложение контракта равновесного ядра

Дата: 2026-11-02  
Статус: проект для интеграции, не утверждённый публичный DTO и не численный benchmark. Код и реализация запрещены до утверждения OpenSpec baseline владельцем.

## 1. Область MVP

Равновесное ядро не является универсальным химическим solver. Ограничить первую версию:
1. pH сильных кислот/оснований в явно обозначенном идеальном разбавленном режиме.
2. Одноосновные слабые кислоты/основания с известными Ka/Kb и материальным балансом.
3. Ограниченные ионные равновесия и осаждение по Ksp при известной активности либо явно выбранном идеальном приближении.
4. Газовые смеси идеальных газов: n, V, T, P и парциальные давления.
5. Газовое химическое равновесие только для реакций с надёжной K и однозначным standard state.

Вне MVP: концентрированные растворы, универсальная модель Дебая–Хюккеля без проверенного диапазона, комплексы, неидеальные газы/fugacity corrections, EOS и сложные многофазные системы.

Температурный диапазон 273.15–373.15 K сам по себе не гарантирует жидкую водную фазу. Фаза зависит от состава, давления и применимости конкретных данных.

## 2. Научные инварианты

- Термодинамическая K выражается через активности относительно стандартных состояний.
- K(activity), Kp, Kc, molality-based constants и эмпирические концентрационные константы — разные basis; нельзя смешивать без явного корректного преобразования.
- pH относится к активности H+; -log10([H+]) разрешено только как явно маркированное идеальное разбавленное приближение.
- Ионные равновесия используют активности, если модель и данные это поддерживают; иначе результат маркируется как идеальное приближение.
- Осаждение требует совместного решения материальных балансов, электронейтральности, активностей и фазового условия насыщения. Одно сравнение Qsp и Ksp не является общим equilibrium solve.
- Для газов MVP использует идеальный газ и partial pressures как явно обозначенное приближение; fugacity coefficient не вычисляется.
- K(T) переносится только по проверенной применимой зависимости или достаточным термодинамическим данным. Молчаливая экстраполяция запрещена.
- MVP изотермический: T фиксирована, thermal evolution не вычисляется.

## 3. Basis и стандартные состояния

Предлагаемые типы EquilibriumBasis (имена предварительные):
- activity — безразмерные активности относительно заданных standard states;
- partial_pressure — отношение парциального давления к standard pressure для идеального газа;
- concentration_ideal — концентрационная форма с явной единицей/шкалой и пометкой приближения;
- molality_ideal — только при отдельном утверждении модели и конвенции;
- empirical_concentration — эмпирическая константа с единицами и точным законом действия масс, не термодинамическая K.

Basis не должен быть произвольной строкой. Автоматическое преобразование разных basis по одному численному значению запрещено.

Предлагаемый StandardStateRef содержит kind, reference value/unit where applicable, convention/source/version, medium/solvent, applicability, activity convention and dimensionless normalization. Единичная активность чистой твёрдой или жидкой фазы допустима только при выполнении предпосылок выбранной модели; нельзя выводить её только из phase label.

Q вычисляется тем же выражением, basis и standard states, что и K. Сравнение Q/K допускается после проверки совместимости basis, T и applicability. Residual ln(Q/K) подходит для положительных Q и K; граничные нулевые активности требуют отдельной обработки, не подстановки epsilon.

## 4. Активности водных растворов

ActivityModelConfig предлагается включить в EquilibriumProblem:
- model_id/model_version;
- mode: ideal_dilute или конкретная отдельно утверждённая модель;
- concentration_scale: molarity или molality;
- solvent/medium reference;
- validity range, включая ionic strength и T/P, если применимо;
- required parameters, provenance и applicability status.

Для ideal_dilute принимается gamma_i = 1 как приближение, результат явно маркируется. Не назначать Debye–Hückel универсальной моделью. В A3 review указано ограничение I < 0.10 mol kg−1 для конкретной IUPAC конвенции/формы уравнения; это не универсальная граница всех моделей и не разрешение экстраполировать.

Не смешивать mol/L и mol/kg без необходимых данных и обоснованного преобразования.

## 5. pH contract

Результат различает:
- thermodynamic_activity_pH — из активности H+ по выбранной конвенции;
- ideal_concentration_approximation — -log10([H+]) при gamma=1;
- unavailable — недостаточно данных/модели.

Результат должен включать value, method/basis, activity model id/version, использованную H+ activity или concentration, T, medium, validity status и warnings. Концентрационное приближение нельзя подписывать просто pH без указания идеального приближения.

## 6. Кислотно-основные равновесия

Для слабой одноосновной кислоты HA ⇌ H+ + A− или основания B + H2O ⇌ BH+ + OH− вход включает:
- balanced Reaction ref;
- typed Ka/Kb (basis, standard state, T, source, uncertainty);
- initial analytical totals;
- charge-balance inputs;
- solvent/water assumptions;
- activity model.

Solver одновременно удовлетворяет материальным балансам аналитических компонентов, электронейтральности и уравнениям равновесия на совместимом Q/K basis. Kw включается, если требуется выбранной постановкой и имеется применимое значение.

Многокомпонентные буферы, полипротонные кислоты, комплексообразование и произвольные сети равновесий не включать без отдельного benchmark.

## 7. Ksp и осаждение

Ksp — typed ThermoConstantRecord с basis/standard state, T, medium, phase, source, uncertainty and validity.

Необходимые условия:
1. Материальный баланс каждого аналитического компонента.
2. Электронейтральность водной фазы.
3. Активности растворённых ионов.
4. Условие насыщения потенциальной твёрдой фазы.
5. Неотрицательное количество твёрдой фазы.
6. Правило появления/исчезновения фазы (complementarity), согласованное с принятой sign convention.

Кандидат для одной твёрдой фазы: solid amount >= 0; SI = ln(Qsp/Ksp); при отсутствии твёрдой фазы SI <= 0; при наличии твёрдой фазы SI = 0 в пределах допуска. Это предложение требует отдельного подтверждения и численной формулировки.

Qsp/Ksp может дать индекс насыщения, но не определяет количество осадка и не закрывает материальный/зарядовый баланс. Расчёт блокируется при отсутствии обязательных totals, charge inputs, Ksp basis/standard state, применимой activity model или сведений о допустимой твёрдой фазе.

## 8. Газовое равновесие MVP

- Газовая смесь: ideal gas law PV=nRT.
- Парциальное давление: p_i = y_i P для идеальной смеси.
- В equilibrium expression использовать dimensionless p_i/p° для pressure standard state.
- Qp и Kp должны использовать одинаковую стехиометрию и standard pressure.
- K(activity) нельзя подменять Kp без термодинамического преобразования.
- Fugacity и fugacity coefficients не вычисляются.
- T/P/composition должны входить в applicability range констант.

Газовые сценарии владельца: 2 NO2(g) ⇌ N2O4(g), H2(g) + I2(g) ⇌ 2 HI(g). Это qualitative scenarios, не численные fixtures.

## 9. Температурная применимость K

ThermoConstantRef включает reference T, pressure/medium, standard state, source/version, uncertainty и validity interval.

Разрешены direct tabulated K при запрошенной T в диапазоне данных или проверенная термодинамическая зависимость с достаточными ΔH°/ΔCp° и явными предпосылками. Запрещено повторно использовать K при другой T без обоснования, экстраполировать за диапазон, смешивать K(T) с Arrhenius k(T) или выводить зависимость из одной точки без достаточных данных.

Если T запроса отличается от reference T и валидированного преобразования нет, solve блокируется.

## 10. Предлагаемые логические DTO

Это предварительные поля, не wire schema.

EquilibriumProblem:
- problem_id, schema_version;
- reaction_refs (Reaction ID + revision);
- initial_analytical_totals (typed amount/concentration scale);
- phase_constraints;
- T, P, medium/solvent;
- equilibrium_constant_refs;
- activity_model_config;
- standard_state_refs;
- selected_model_id/version;
- numerical policy/tolerances ref;
- provenance/data versions.

EquilibriumResult:
- status: converged | blocked | no_solution | ambiguous | numerical_failure | out_of_domain;
- species_results: SpeciesRef, amount/concentration, activity, activity coefficient if computed, phase;
- typed pH_result;
- saturation_results: Qsp, Ksp, SI, solid amount and phase status;
- reaction_residuals (ln(Q/K) or explicitly selected residual);
- mass_balance_residuals and charge_balance_residual;
- numerical diagnostics, model/data refs, warnings and applicability status.

ActivityModelConfig:
- model_id/version, mode, concentration_scale;
- parameter refs and validity domain;
- required inputs and applicability diagnostics.

EquilibriumConstantRef ссылается на A1 ThermoConstantRecord; A3 не дублирует raw constants/provenance.

## 11. Кандидаты subsystem error codes

EQUILIBRIUM_BASIS_MISMATCH; EQUILIBRIUM_STANDARD_STATE_MISMATCH; EQUILIBRIUM_CONSTANT_OUT_OF_RANGE; EQUILIBRIUM_ACTIVITY_MODEL_OUT_OF_DOMAIN; EQUILIBRIUM_MISSING_ANALYTICAL_TOTAL; EQUILIBRIUM_MISSING_CHARGE_BALANCE_INPUT; EQUILIBRIUM_MISSING_K_OR_KSP; EQUILIBRIUM_PHASE_UNSUPPORTED; EQUILIBRIUM_GAS_NONIDEAL_OUT_OF_SCOPE; EQUILIBRIUM_NO_SOLUTION; EQUILIBRIUM_AMBIGUOUS; EQUILIBRIUM_NUMERICAL_FAILURE; EQUILIBRIUM_MASS_BALANCE_RESIDUAL; EQUILIBRIUM_CHARGE_BALANCE_RESIDUAL; EQUILIBRIUM_SATURATION_RESIDUAL.

Коды — предложения; общий DomainError envelope утверждает интегратор.

## 12. Acceptance tests

Scientific invariants:
- Material balance каждого аналитического компонента.
- Независимая проверка электронейтральности.
- Equilibrium residual ln(Q/K) близок к нулю на выбранном совместимом basis.
- Precipitation solution удовлетворяет mass balance, charge balance, nonnegative solid amount и saturation/complementarity.
- Ideal gas law и gas material balance проверяются отдельно от chemical equilibrium.
- Никакого out-of-domain результата или молчаливой экстраполяции.

Negative/blocked:
- K(activity) передана pressure-basis solve без преобразования → basis mismatch.
- Ksp без standard state/T/source → blocked.
- Концентрационный pH выдан как thermodynamic pH → contract failure.
- Activity model вне ionic-strength/T domain → blocked/out_of_domain.
- Нет analytical total или charge input → blocked.
- Qsp выше Ksp без solve количества осадка не даёт права заявлять equilibrium result.
- T отличается от reference T и нет K(T) relation → blocked.
- Nonideal gas/fugacity запрошены → unsupported in MVP.
- Нет совместимого standard pressure → blocked.

Численные fixtures должны включать условия, единицы, reaction/species, T/P, basis/standard state, activity model, источник/версию/лицензию, uncertainty/significant digits, независимо полученный expected result и отдельные допуски mass/charge/equilibrium residual. A3 review не содержит численных эталонных значений; не добавлять их догадкой.

## 13. Межагентные границы и открытые решения

- A1 owns ThermoConstantRecord, PropertyRecord, provenance, units and uncertainty.
- A2 owns FormulaAST, SpeciesRef, Reaction and balance invariants.
- A3 owns equilibrium formulation, basis compatibility, activity config, pH/Ksp semantics and residuals.
- A4 owns kinetics; K alone не задаёт time scale или rate law.
- A5 показывает blocked/out-of-domain/approximation и reliability vector.

Открыты: INT-04 basis/standard-state schema; INT-05 gas pressure standard state; INT-06 конкретная activity model по aqueous benchmarks; INT-07 typed pH result; INT-08 precipitation complementarity; INT-09 K(T) derivation/uncertainty; INT-13/14/15/22 units, missing semantics, error envelope и tolerances. Solver algorithm намеренно не выбирается.

## 14. Рекомендация A3

Сначала утвердить постановки и applicability gates, затем подготовить source-backed numeric fixtures. Не выбирать универсальную activity model и не добавлять численные константы без проверенных источников. Реализация остаётся заблокированной до утверждения OpenSpec baseline владельцем.
