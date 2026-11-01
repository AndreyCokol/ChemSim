# ChemSim

Офлайн-симулятор химических экспериментов на Godot 4.x для Windows 10/11 x64.

## Текущий статус

Реализация начата после явного подтверждения владельцем OpenSpec baseline. Текущий срез включает:
- технический каркас приложения Godot;
- разбор простых химических формул, вложенных круглых групп, фаз и зарядов;
- разбор уравнений со стрелками `->` и `<->`;
- стехиометрическую балансировку по элементному составу и отдельной строке электрического заряда;
- минимальный UI для проверки формул и балансировки уравнения.

Это **не** готовый химический симулятор: каталог проверенных веществ, равновесные модели, кинетика, численный ODE solver, графики и полноценная энциклопедия ещё не реализованы.

## Запуск

1. Установите Godot 4.x.
2. Откройте в Godot файл `project.godot`.
3. Нажмите Run Project.

## Проверка

Из корня проекта:

```sh
godot --headless --path . --script res://tests/test_formula_parser.gd
godot --headless --path . --script res://tests/test_reaction_balancer.gd
```

Тесты добавлены, но пока не запускались в этом облачном цикле: требуется Godot 4.x runtime.

## Синтаксис и ограничения

- Формулы: простые символы элементов и вложенные круглые группы, например `Ca(OH)2`.
- Фазы: `(s)`, `(l)`, `(g)`, `(aq)`.
- Заряд: явная запись с кареткой `SO4^2-`, `Fe^3+`; краткая форма однозарядных частиц `H+`, `OH-`.
- Уравнение: `H2 + O2 -> H2O`; разделитель веществ — плюс с пробелами вокруг него. Это не позволяет спутать плюс-разделитель с зарядом иона.
- Коэффициент задаётся перед формулой через пробел: `2 H2 + O2 -> 2 H2O`.
- Балансировщик учитывает атомы каждого элемента и суммарный заряд. Если пространство решений неоднозначно, нет положительного решения или не удаётся подтвердить целые коэффициенты в ограниченном диапазоне, он возвращает ошибку вместо произвольного выбора.
- Численный RREF сейчас использует double precision и проверку остатка; это предварительная реализация, не сертифицированный exact-rational solver. Перед научно значимым использованием требуется замена/подтверждение точной рациональной арифметикой и тестирование.
- Гидраты, комплексы, структурные формулы, редокс-полуреакции и расширенный синтаксис пока не поддерживаются.

## Domain data contracts (early)

The domain layer now has initial records:
- `PropertyRecord`: value, unit, uncertainty, source, source version, conditions, validity ranges, license identifier and quality status.
- `SubstanceRecord`: stable catalog identity and formula/composition, with phase deliberately excluded from the substance identity.
- `SpeciesRef`: references a substance in a particular phase/context.
- `ExperimentComponent`: experiment-local amount and optional initial state.

A property is usable for scientific calculations only when it has a value, unit, source reference, license identifier and `verified` quality status. An absent or incomplete property is not replaced by an estimated default. An unknown hazard status is not equivalent to safe.

These are initial GDScript domain records, not yet a complete validated persistence schema. Dataset licensing remains per-source/per-field; no broad external chemistry dataset is bundled by this change.
