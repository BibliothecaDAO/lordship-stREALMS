mod burner;
mod dlords;
mod reward_pool;
mod velords;

pub mod interfaces {
    pub mod IBurner;
    pub mod IERC20;
    pub mod IRewardPool;
    pub mod IVE;
}

// only used in tests, but can't be #[cfg(test)]
pub mod mocks {
    pub mod erc20;
}

#[cfg(test)]
mod tests {
    pub mod common;
    mod test_reward_pool;
    mod test_velords;
}
