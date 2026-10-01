#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum DuplicateCheck {
    New,
    Duplicate,
    TooOld,
}

#[derive(Debug, Clone)]
pub struct DuplicateChecker {
    ids: Vec<i64>,
    capacity: usize,
}

impl DuplicateChecker {
    pub fn new(capacity: usize) -> Self {
        Self {
            ids: Vec::with_capacity(capacity * 2),
            capacity,
        }
    }

    pub fn check(&mut self, id: i64) -> DuplicateCheck {
        if self.ids.len() == self.capacity * 2 {
            self.ids.drain(..self.capacity);
        }
        match self.ids.last() {
            None => {
                self.ids.push(id);
                return DuplicateCheck::New;
            }
            Some(&last) if id > last => {
                self.ids.push(id);
                return DuplicateCheck::New;
            }
            _ => {}
        }
        if self.ids.len() >= self.capacity && id < self.ids[0] {
            return DuplicateCheck::TooOld;
        }
        match self.ids.binary_search(&id) {
            Ok(_) => DuplicateCheck::Duplicate,
            Err(position) => {
                self.ids.insert(position, id);
                DuplicateCheck::New
            }
        }
    }

    pub fn contains(&self, id: i64) -> bool {
        self.ids.binary_search(&id).is_ok()
    }

    pub fn oldest(&self) -> Option<i64> {
        self.ids.first().copied()
    }

    pub fn clear(&mut self) {
        self.ids.clear();
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use proptest::prelude::*;

    #[test]
    fn detects_duplicates_and_out_of_order() {
        let mut checker = DuplicateChecker::new(4);
        assert_eq!(checker.check(10), DuplicateCheck::New);
        assert_eq!(checker.check(30), DuplicateCheck::New);
        assert_eq!(checker.check(20), DuplicateCheck::New);
        assert_eq!(checker.check(20), DuplicateCheck::Duplicate);
        assert_eq!(checker.check(30), DuplicateCheck::Duplicate);
        assert!(checker.contains(10));
    }

    #[test]
    fn forgets_oldest_beyond_capacity() {
        let mut checker = DuplicateChecker::new(3);
        for id in 1..=6 {
            assert_eq!(checker.check(id * 10), DuplicateCheck::New);
        }
        assert_eq!(checker.check(70), DuplicateCheck::New);
        assert_eq!(checker.check(5), DuplicateCheck::TooOld);
    }

    proptest! {
        #[test]
        fn never_accepts_same_id_twice_within_window(ids in proptest::collection::vec(0i64..500, 1..300)) {
            let mut checker = DuplicateChecker::new(1000);
            let mut seen = std::collections::HashSet::new();
            for id in ids {
                let result = checker.check(id);
                if seen.contains(&id) {
                    prop_assert_eq!(result, DuplicateCheck::Duplicate);
                } else {
                    prop_assert_eq!(result, DuplicateCheck::New);
                    seen.insert(id);
                }
            }
        }
    }
}
