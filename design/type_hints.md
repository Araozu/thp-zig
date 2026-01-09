```c


String thing = "hello"
val thing: String = "hello"

fun thing_doer(Thing t) -> Unit {}
fun thing_doer(t: Thing) -> Unit {}

fun thing_doer(Box[Stuff] t) -> Unit {}
fun thing_doer(t: Box[Stuff]) -> Unit {}

fun thing_doer[A](Box[A] t) -> Unit {}
fun thing_doer[A](t: Box[A]) -> Unit {}

fun my_socket(self, mut Box box) {}
fun my_socket(self, box: mut Box) {}

class Box {
    var I32 stuff

    fun add_stuff(mut self, I32 value) {}

    fun compute_then(mut self, mut Box[A]? other) {}
}

class Box {
    var stuff: I32

    fun add_to(mut self, value: I32) {
        self.stuff += value
    }

    fun compute_then(mut self, other: ?mut Box[A]) {
        //
    }
}


```
