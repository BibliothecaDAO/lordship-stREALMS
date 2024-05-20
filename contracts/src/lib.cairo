mod lordship;
mod components {
    mod strealm;
    mod erc721 {
        mod extensions;
    }
}

mod tests {
    mod unit {
        #[cfg(test)]
        mod test_strealm_component;
    }
    mod integration {
        #[cfg(test)]
        mod test_lordship;
    }
    mod mocks {
        mod erc20_mock;
        mod strealm_mock;
        mod account_mock;
    }
}
