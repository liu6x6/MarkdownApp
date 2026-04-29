# React Native 核心概念解析与 SwiftUI 对比

本文档整理了 React Native 中最核心的四个概念（Props, useState, useEffect, Refs）的区别，以及与 SwiftUI 中 `@Binding` 的等价实现方式，并深入剖析了 `useState` 和 `useRef` 的底层运行原理。

---

## 一、 四大核心概念：打工人的“任务书、记忆、口袋与动作”

我们可以把一个 RN 组件想象成一个**“打工人”**，这四个概念分别是：

### 1. Props (属性) —— “老板给的任务书”
* **本质**：父组件传递给子组件的数据。
* **特点**：**绝对只读（Immutable）**。子组件绝不能直接修改自己的 props。
* **使用场景**：配置组件，或者把父组件的数据传给子组件显示。
```javascript
const UserCard = ({ name }) => {
  return <Text>Hello, {name}!</Text>;
}
```

### 2. useState (状态) —— “组件的个人记忆”
* **本质**：组件内部私有的状态数据。
* **特点**：**响应式**。修改它（通过 `setState`）会触发组件**重新渲染（Re-render）**以更新 UI。
* **使用场景**：任何需要在界面上发生变化的数据（输入框文字、开关状态等）。
```javascript
const Counter = () => {
  const [count, setCount] = useState(0);
  return <Button title={`点了 ${count} 次`} onPress={() => setCount(count + 1)} />;
}
```

### 3. Refs (useRef) —— “组件的秘密口袋” / “原生遥控器”
* **本质**：跨越多次渲染周期的“盒子”，通过 `.current` 存放可变数据。
* **特点**：修改 Ref 的值**完全不会触发界面重新渲染**。常用来直接获取底层原生组件的引用。
* **使用场景**：
  1. 存数据但不需刷新 UI（如定时器ID、防止连点记录）。
  2. 调用原生组件方法（如输入框自动聚焦 `ref.current.focus()`）。
```javascript
const Timer = () => {
  const timerId = useRef(null); 
  const start = () => {
    timerId.current = setInterval(() => console.log('滴答'), 1000);
  };
}
```

### 4. useEffect (副作用) —— “渲染完成后的连带动作”
* **本质**：处理“不直接参与界面绘制，但必须要做的事情”（副作用）。
* **特点**：在组件**渲染到屏幕上之后**执行。受“依赖数组”控制，依赖变了才会再次执行。
* **使用场景**：网络请求、监听状态变化、设置订阅/定时器等。
```javascript
const UserProfile = ({ userId }) => {
  const [data, setData] = useState(null);

  useEffect(() => {
    fetchUserData(userId).then(res => setData(res));
  }, [userId]); // 依赖项：userId 变了才重新请求
}
```

---

## 二、 RN 中如何实现 SwiftUI 的 `@Binding`？

React Native 中**没有** `@Binding` 这种双向绑定的语法糖，因为 RN 严格遵守**单向数据流 (One-Way Data Flow)**。

在 RN 中实现 `@Binding` 同样效果的标准方法是：**状态 (State) + 回调函数 (Callback)**。

### SwiftUI 写法 (@Binding)
```swift
// 父组件
struct ParentView: View {
    @State private var text = ""
    var body: some View {
        ChildView(text: $text) 
    }
}

// 子组件
struct ChildView: View {
    @Binding var text: String
    var body: some View {
        TextField("输入内容", text: $text)
    }
}
```

### React Native 等价写法 (Props + 回调)
需要明确地把“值”和“修改值的方法”分开传给子组件：

```javascript
// 父组件
const ParentView = () => {
  const [text, setText] = useState("");
  return (
    <View>
      {/* 将 值(text) 和 修改方法(setText) 分别传给子组件 */}
      <ChildView text={text} onTextChange={setText} />
    </View>
  );
};

// 子组件
const ChildView = ({ text, onTextChange }) => {
  return (
    <TextInput 
      value={text} 
      onChangeText={onTextChange} 
      placeholder="输入内容"
    />
  );
};
```

---

## 三、 深入底层：useState 与 useRef 的运行原理

### 🚨 核心纠误：Refs (useRef) 有依赖项吗？
**答案是：没有！完全没有！** 
`useRef` 根本不存在“依赖项”（Dependency Array）这个概念。
“依赖项”（比如 `[a, b]`）是属于 `useEffect`、`useCallback`、`useMemo` 等 Hooks 的，用于告诉 React **什么时候该重新执行里面的逻辑**。而 `useRef` 的作用只是**“给你一个永远都在的空盒子”**，不需要重新计算，也不需要重新执行，因此它的用法永远只有 `const myRef = useRef(初始值);`。

### 1. useState 的运行原理
在类组件时代，状态是存在组件实例里的。但函数组件只是一个普通的函数，执行完变量就会销毁。
* **底层原理**：当你调用 `useState` 时，React 会在幕后（一个叫 **Fiber** 的底层数据结构上）为这个组件开辟一块空间，相当于建了一个**链表（或数组）**来存放状态。
* **运行流程**：
  1. **初次渲染（Mount）**：React 在幕后账本按顺序记下初始值和修改方法，并返回给组件渲染。
  2. **发生修改**：你调用 `setCount(1)`，React 收到通知，将组件标记为“脏数据（Dirty）”，并**重新调用你的组件函数**。
  3. **重新渲染（Re-render）**：组件函数再次运行到 `useState` 时，React 会去幕后账本里查最新值并返回，界面随之更新。
* **⚠️ 为什么 Hooks 不能写在 if 语句里？**
  因为 React 幕后的账本是**没有名字的，纯靠“调用顺序（索引）”来记账**。如果放在 `if` 里导致某次渲染跳过了一个 Hook，后续所有的 Hook 对应的数据都会错位，导致状态大乱。

### 2. useRef 的运行原理
在 React 源码中，`useRef` 本质上可以理解为一个“阉割版”的 `useState`。
* **底层原理**：当你调用 `const myRef = useRef(0)` 时，React 只是在幕后账本（Fiber）里存了一个普通的 JavaScript 对象：`{ current: 0 }`，然后把这个对象的**内存地址（引用）**交给了你。
* **为什么它不会触发重新渲染？**
  因为修改时使用的是 `myRef.current = 1;`，这仅仅是**普通的 JavaScript 对象属性赋值**。你偷偷换了盒子里面的东西，**没有通知 React**，既然 React 不知道，它自然就不会去重新渲染组件。
* **为什么每次渲染它都不变？（与普通变量的区别）**
  如果只是普通的 `let myVar = { current: 0 }` 写在组件里，每次组件重新渲染（函数重新执行）时，`myVar` 都会被重新创建，之前的值就丢了。而 `useRef` 会把对象保存在幕后账本上，无论函数执行多少次，它都会返回**同一个对象的内存地址**。

### 💡 核心总结 (银行柜台比喻)
把 React 想象成一个**银行柜台**，组件就是**来办业务的客户**：

| 工具 | 原理比喻 | 动作与后果 |
| :--- | :--- | :--- |
| **普通变量**<br>`let a = 1` | 客户写在草稿纸上的字。 | 每次重新办业务（重新渲染），草稿纸都会被扔掉重写。**记不住值**。 |
| **useState** | 客户在柜台办理了“存款”。 | 你存了钱（`setState`），银行系统会有**交易流水记录（触发重新渲染）**，下次来钱还在。 |
| **useRef** | 客户在银行租了一个**“保险柜”**。 | 随时用钥匙（`.current`）存取东西。**银行不管你放了什么，也不记录流水（不触发渲染）**，但东西永远都在。 |