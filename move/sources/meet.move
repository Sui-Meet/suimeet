#[allow(unused_function, unused_use, unused_variable, unused_mut_parameter, lint(share_owned))]
module love::meet{
    use sui::event;
    use sui::tx_context::{sender};
    use std::string::{Self, String};
    use sui::package;
    use sui::display;
    use sui::table::{Self, Table};
    use sui::address;

    #[test_only]
    use sui::test_scenario::{Self, ctx};
    #[test_only]
    use sui::test_utils::assert_eq;

    //==============================================================================================
    // Constants
    //==============================================================================================
    
    const BASE36: vector<u8> = b"0123456789abcdefghijklmnopqrstuvwxyz";
    const VISUALIZATION_SITE: address =
        @0xe85a97a3e07f984c53e1a8a1dc6bd32ebec4e48610b3191e4e2e911eccabcb9b;
    
    //==============================================================================================
    // Error codes
    //==============================================================================================
    /// You need to create a profile of your own before you can like other profile
    const ENoProfile: u64 = 0;
    /// You already have a profile
    const EProfileExist: u64 = 1;

    //==============================================================================================
    // Structs 
    //==============================================================================================
    public struct State has key {
        id: UID,
        accounts: Table<address, ID>,
        all_profiles: vector<ID>
    }

    public struct Profile has key{
        id: UID,
        owner: address,
        b36addr: String,
        photo_blob: String, //blob_id
        photo_url: String,
        description: String, //max 50 words
        contact: String, // tg/wechat
        likes: vector<ID>, //<profile_id of likers>
    }

    // OTW for display.
    public struct MEET has drop {}   
    //==============================================================================================
    // Event Structs 
    //==============================================================================================

    public struct ProfileCreated has copy, drop {
        id: ID,
        owner: address,
    }

    public struct ProfileLiked has copy, drop {
        profile: ID,
        owner: address,
        liker: address,
    }

    //==============================================================================================
    // Init
    //==============================================================================================

    fun init(otw: MEET, ctx: &mut TxContext) {
        let publisher = package::claim(otw, ctx);
        let mut display = display::new<Profile>(&publisher, ctx);

        display.add(
            b"link".to_string(),
            b"https://{b36addr}.walrus.site".to_string(),
        );
        display.add(
            b"image_url".to_string(),
            b"{photo_url}+{id}".to_string(),
        );
        display.add(
            b"walrus site address".to_string(),
            VISUALIZATION_SITE.to_string(),
        );
        display.update_version();

        transfer::share_object(State{
            id: object::new(ctx), 
            accounts: table::new(ctx),
            all_profiles: vector::empty(),
        });
        transfer::public_transfer(publisher, ctx.sender());
        transfer::public_transfer(display, ctx.sender());
    }

    //==============================================================================================
    // Entry Functions 
    //==============================================================================================

    public entry fun create_profile(
        state: &mut State,
        photo_blob: String,
        photo_url: String,
        //max 50 words, suggestion: age, gender, job, hobbies
        description: String, 
        contact: String, //tg/wechat
        ctx: &mut TxContext
    ){
        let owner = tx_context::sender(ctx);
        assert!(!table::contains(&state.accounts, owner), EProfileExist);
        let uid = object::new(ctx);
        let id = object::uid_to_inner(&uid);
        let b36addr = to_b36(uid.uid_to_address());
        let new_profile = Profile {
            id: uid,
            owner,
            b36addr,
            photo_blob,
            photo_url,
            description,
            contact, // tg/wechat
            likes: vector::empty(), //<profile_id of likers>
        };
        transfer::share_object(new_profile);
        table::add(&mut state.accounts, owner, id);
        vector::push_back(&mut state.all_profiles, id);
        event::emit(ProfileCreated{
            id,
            owner,
        });
    }

    public entry fun like_profile(
        profile: &mut Profile,
        state: &mut State,
        ctx: &mut TxContext
    ){
        let liker = tx_context::sender(ctx);
        assert!(table::contains(&state.accounts, liker), ENoProfile);
        let liker_profile = table::borrow(&state.accounts, liker);
        vector::push_back(&mut profile.likes, *liker_profile);
        event::emit(ProfileLiked{
            profile: object::uid_to_inner(&profile.id),
            owner: profile.owner,
            liker
        });
    }

    //==============================================================================================
    // Getter Functions 
    //==============================================================================================

    

    //==============================================================================================
    // Helper Functions 
    //==============================================================================================

    public fun to_b36(addr: address): String {
        let source = address::to_bytes(addr);
        let size = 2 * vector::length(&source);
        let b36copy = BASE36;
        let base = vector::length(&b36copy);
        let mut encoding = vector::tabulate!(size, |_| 0);
        let mut high = size - 1;

        source.length().do!(|j| {
            let mut carry = source[j] as u64;
            let mut it = size - 1;
            while (it > high || carry != 0) {
                carry = carry + 256 * (encoding[it] as u64);
                let value = (carry % base) as u8;
                *&mut encoding[it] = value;
                carry = carry / base;
                it = it - 1;
            };
            high = it;
        });

        let mut str: vector<u8> = vector[];
        let mut k = 0;
        let mut leading_zeros = true;
        while (k < vector::length(&encoding)) {
            let byte = encoding[k] as u64;
            if (byte != 0 && leading_zeros) {
                leading_zeros = false;
            };
            let char = b36copy[byte];
            if (!leading_zeros) {
                str.push_back(char);
            };
            k = k + 1;
        };
        str.to_string()
    }


}