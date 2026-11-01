# Раунд 1 — ревью A4: Kinetics & Numerical Solver

Статус: профильное ревью завершено.

## Вывод
Solver следует проектировать как независимое численное ядро с контролем ошибок, физико-химических инвариантов и журналом событий. Нельзя зафиксировать один интегратор до benchmark.

## Критические замечания
1. **Разделить три задачи:** термодинамический equilibrium solve; кинетическая ODE во времени; energy/thermal model. Их входы и результаты различны.
2. **K не задаёт временной масштаб.** K определяет равновесное состояние. Для временного процесса нужны rate law, reaction orders, k(T), и модель обратного направления. Нельзя универсально подставлять kf/kr = K: соотношение зависит от закона скорости, стандартных состояний и единиц/порядков.
3. **Аррениус.** Сохранять reference temperature и reference rate constant; параметры должны иметь размерности и применимый температурный интервал. Ea и R должны быть в согласованных единицах.
4. **Выбор интегратора.** Нежёсткие системы: explicit adaptive RK (например RK45/DOP853); жёсткие: implicit Radau/BDF или LSODA с обнаружением жёсткости. Это ориентир по solver class, а не решение о библиотеке/языке реализации. Выбор подтвердить benchmark. SciPy documentation описывает именно это разделение.
5. **Положительность.** Не обрезать отрицательные концентрации безусловно: clipping меняет балансы. Использовать positivity-aware step control/коррекцию с проверкой балансов и сообщать о неудаче.
6. **Открытые системы.** Материальный баланс включает стехиометрический член реакции и потоковые члены. Дискретные события должны применяться точно на границе времени, а не теряться внутри шага.
7. **Температура-время.** Сейчас продукт требует график T(t), но не определена модель энергообмена. Предлагается: MVP по умолчанию изотермический (T постоянна и график это показывает); не-изотермический режим — отдельный модуль только при наличии ΔH реакций, Cp компонентов/сосуда, теплопотерь/теплообмена и граничных условий. Нельзя выводить T(t) только из кинетики.
8. **Rewind и воспроизводимость.** В snapshot/event log хранить начальное состояние, все discrete events, flow schedules, версии данных/модели, solver settings/tolerances, шаги/события и seed, если появится стохастика.
9. **Конечное смешивание.** Не включать псевдосмешивание через визуальную анимацию. Нужна проверенная compartment/mixing model с параметрами; до этого функция заблокирована.

## Benchmark требования
- Аналитические first-order decay и reversible first-order reaction.
- Arrhenius ratio at two temperatures.
- Conservation in closed systems.
- Open-system constant inflow/outflow.
- Event insertion at exact timestamp.
- Stiff benchmark vs non-stiff benchmark.
- Deterministic replay within declared tolerances.
- Failure cases: missing k/Ea/K, negative concentrations, solver divergence.

## Ссылки
- https://docs.scipy.org/doc/scipy/reference/generated/scipy.integrate.solve_ivp.html
- https://goldbook.iupac.org/terms/view/C01023
- https://goldbook.iupac.org/terms/view/E02177
